import React, { useEffect, useMemo, useRef, useState } from 'react'
import { SafeAreaView, View, Text, TextInput, Button, FlatList, TouchableOpacity } from 'react-native'
import AsyncStorage from '@react-native-async-storage/async-storage'
import { api, setAuth, API_BASE } from './api'

export default function App() {
  const [stage, setStage] = useState('auth') // 'auth' | 'friends' | 'chat'
  const [username, setUsername] = useState('')
  const [deviceToken, setDeviceToken] = useState('')
  const [token, setToken] = useState(null)

  const [friends, setFriends] = useState([])
  const [selectedFriend, setSelectedFriend] = useState(null)
  const [newFriend, setNewFriend] = useState('')
  const [text, setText] = useState('')

  const wsRef = useRef(null)
  const [msgs, setMsgs] = useState([]) // in-memory per session

  const [autoLogin, setAutoLogin] = useState(false)

  // --- helpers ---
  const connectWS = jwt => {
    const ws = new WebSocket(`${API_BASE.replace('http', 'ws')}/ws?token=${jwt}`)
    ws.onopen = () => console.log('WS connected')
    ws.onmessage = e => {
      const m = JSON.parse(e.data)
      if (m.type === 'chat') {
        setMsgs(prev => [...prev, { from: m.from, text: m.text, ts: m.ts }])
      }
    }
    ws.onclose = () => console.log('WS closed')
    wsRef.current = ws
  }

  async function handleRegister() {
    if (!username) return
    const { data } = await api.post('/register', { username })
    setDeviceToken(data.deviceToken)
    // save deviceToken to local storage
    await AsyncStorage.setItem('credentials', JSON.stringify({ username, deviceToken }))
  }

  // check local storage for credentials
  useEffect(() => {
    console.log('Checking local storage for credentials')
    AsyncStorage.getItem('credentials')
      .then(credentials => {
        if (credentials) {
          credentials = JSON.parse(credentials)
          console.log('Credentials:', credentials)
          setUsername(credentials.username)
          setDeviceToken(credentials.deviceToken)
          setAutoLogin(true)

          // handleLogin()
        } else {
          setStage('auth')
        }
      })
      .catch(error => {
        console.error('Error checking local storage for credentials:', error)
      })
  }, [])

  async function handleLogin() {
    const { data } = await api.post('/login', { username, deviceToken })
    setToken(data.token)
    setAuth(data.token)
    connectWS(data.token)
    await refreshFriends()
    setStage('friends')
    if (autoLogin) {
      setStage('friends')
    } else {
      // save deviceToken to local storage
      await AsyncStorage.setItem('credentials', JSON.stringify({ username, deviceToken }))
    }
  }

  async function addFriend(friendUsername) {
    console.log('Adding friend:', friendUsername)
    try {
      await api.post('/friends/add', { friendUsername })
    } catch (error) {
      if (error.response.status === 404) {
        alert('User not found')
      } else {
        console.error('Error adding friend:', error)
      }
    }
    await refreshFriends()
  }

  async function refreshFriends() {
    const { data } = await api.get('/friends')
    setFriends(data.friends)
  }

  // --- UI states ---
  if (stage === 'auth') {
    return (
      <SafeAreaView style={{ padding: 16 }}>
        <Text style={{ fontSize: 22, fontWeight: '600' }}>Whsip (MVP)</Text>

        <Text style={{ marginTop: 16 }}>Username</Text>
        <TextInput
          value={username}
          onChangeText={setUsername}
          style={{ borderWidth: 1, padding: 8, borderRadius: 6 }}
          autoCapitalize="none"
        />

        <View style={{ height: 8 }} />
        <Button title="Register (get device token)" onPress={handleRegister} />
        {deviceToken ? (
          <Text selectable style={{ marginTop: 8, fontSize: 12 }}>
            Device Token (save securely): {deviceToken}
          </Text>
        ) : null}

        <View style={{ height: 16 }} />
        <Text>Device Token</Text>
        <TextInput
          value={deviceToken}
          onChangeText={setDeviceToken}
          style={{ borderWidth: 1, padding: 8, borderRadius: 6 }}
          autoCapitalize="none"
        />
        <View style={{ height: 8 }} />
        <Button title="Login" onPress={handleLogin} />
      </SafeAreaView>
    )
  }

  if (stage === 'friends') {
    return (
      <SafeAreaView style={{ flex: 1, padding: 16 }}>
        <Text style={{ fontSize: 18, fontWeight: '600' }}>Hello, {username}</Text>
        <View style={{ flexDirection: 'row', gap: 8, marginTop: 12 }}>
          <TextInput
            placeholder="Add friend by username"
            value={newFriend}
            onChangeText={setNewFriend}
            style={{ flex: 1, borderWidth: 1, padding: 8, borderRadius: 6 }}
          />
          <Button
            title="Add"
            onPress={async () => {
              await addFriend(newFriend.trim())
              setNewFriend('')
            }}
          />
        </View>

        <View style={{ height: 12 }} />
        <Button title="Refresh" onPress={refreshFriends} />

        <FlatList
          style={{ marginTop: 16 }}
          data={friends}
          keyExtractor={x => x.username}
          renderItem={({ item }) => (
            <TouchableOpacity
              onPress={() => {
                setSelectedFriend(item.username)
                setStage('chat')
              }}
            >
              <View
                style={{
                  paddingVertical: 12,
                  borderBottomWidth: 1,
                  borderColor: '#eee',
                }}
              >
                <Text style={{ fontSize: 16 }}>
                  {item.username} {item.online ? '🟢' : '⚪️'}
                </Text>
              </View>
            </TouchableOpacity>
          )}
        />
      </SafeAreaView>
    )
  }

  if (stage === 'chat') {
    function send() {
      if (!text || !wsRef.current) return
      wsRef.current.send(JSON.stringify({ type: 'chat', to: selectedFriend, text }))
      setMsgs(prev => [...prev, { from: 'me', text, ts: Date.now() }])
      setText('')
    }
    return (
      <SafeAreaView style={{ flex: 1, padding: 16 }}>
        <Text style={{ fontSize: 16, fontWeight: '600' }}>Chat with {selectedFriend}</Text>

        <FlatList
          style={{ marginTop: 12, flex: 1 }}
          data={msgs.filter(m => m.from === 'me' || m.from === selectedFriend)}
          keyExtractor={(_, i) => String(i)}
          renderItem={({ item }) => (
            <View style={{ paddingVertical: 6 }}>
              <Text>
                <Text style={{ fontWeight: '600' }}>{item.from === 'me' ? 'You' : item.from}:</Text> {item.text}
              </Text>
            </View>
          )}
        />

        <View style={{ flexDirection: 'row', gap: 8 }}>
          <TextInput
            value={text}
            onChangeText={setText}
            placeholder="Type…"
            style={{ flex: 1, borderWidth: 1, padding: 8, borderRadius: 6 }}
          />
          <Button title="Send" onPress={send} />
        </View>

        <View style={{ height: 8 }} />
        <Button
          title="Back to friends"
          onPress={() => {
            setMsgs([])
            setStage('friends')
          }}
        />
      </SafeAreaView>
    )
  }

  return null
}
