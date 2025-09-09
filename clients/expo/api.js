import axios from 'axios';
export const API_BASE = 'http://localhost:4000'; // change to your server

export const api = axios.create({ baseURL: API_BASE });

export function setAuth(token) {
  api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
}
