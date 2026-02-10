# VPN Proxy Controller - Privacy-First Android App

## Project Overview
This is a privacy-first Android VPN/Proxy controller application built with Flutter. The app allows users to:
- Control WireGuard VPN connections using user-provided configurations
- Manage SOCKS5/Shadowsocks proxy connections  
- Implement secure server rotation
- Maintain strict privacy standards with no tracking or analytics

## Architecture
- **Frontend**: Flutter (Dart) with Material 3 UI
- **Backend**: Android VpnService with WireGuard Go
- **State Management**: Riverpod for reactive state management
- **Security**: Kill-switch, DNS leak protection, encrypted local storage
- **Privacy**: Zero backend cost, no user accounts, no tracking

## Development Guidelines
- Maintain clean architecture separation (UI/Logic/Platform)
- Implement comprehensive security measures
- Follow Android VPN best practices
- Ensure zero-logging and privacy-first design
- Support both phone and tablet layouts

## Key Components
- VPN configuration management
- WireGuard tunnel control
- Proxy chain integration
- Server rotation logic
- Kill-switch implementation
- Secure storage for configs