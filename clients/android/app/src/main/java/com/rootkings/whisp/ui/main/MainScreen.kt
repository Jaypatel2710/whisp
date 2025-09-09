package com.rootkings.whisp.ui.main

import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.rootkings.whisp.models.AppStage
import com.rootkings.whisp.ui.auth.AuthScreen
import com.rootkings.whisp.ui.chat.ChatScreen
import com.rootkings.whisp.ui.friends.FriendsScreen
import com.rootkings.whisp.viewmodel.MainViewModel

@Composable
fun MainScreen(
    modifier: Modifier = Modifier,
    viewModel: MainViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    
    when (uiState.currentStage) {
        AppStage.AUTH -> {
            AuthScreen(
                username = uiState.username,
                onUsernameChange = viewModel::updateUsername,
                deviceToken = uiState.deviceToken,
                onDeviceTokenChange = viewModel::updateDeviceToken,
                errorMessage = uiState.errorMessage,
                isLoading = uiState.isLoading,
                onRegister = viewModel::register,
                onLogin = viewModel::login,
                modifier = modifier
            )
        }
        AppStage.FRIENDS -> {
            FriendsScreen(
                username = uiState.username,
                friends = uiState.friends,
                errorMessage = uiState.errorMessage,
                isLoading = uiState.isLoading,
                onAddFriend = viewModel::addFriend,
                onRefreshFriends = viewModel::refreshFriends,
                onSelectFriend = viewModel::selectFriend,
                onLogout = viewModel::logout,
                modifier = modifier
            )
        }
        AppStage.CHAT -> {
            ChatScreen(
                selectedFriend = uiState.selectedFriend,
                messages = uiState.messages,
                onSendMessage = viewModel::sendMessage,
                onBackToFriends = viewModel::backToFriends,
                modifier = modifier
            )
        }
    }
}
