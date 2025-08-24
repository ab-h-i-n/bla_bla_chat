import 'dart:async';
import 'package:bla_bla/widgets/user_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;
  GoogleSignInAccount? _currentUser;
  String _errorMessage = '';
  
  late AnimationController _fadeAnimationController;
  late AnimationController _bounceAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _bounceAnimation;

  // Replace with your actual Web Client ID from Google Cloud Console
  static const String? _webClientId = '830134928616-rb2tnnnf11mnd0sk20hjnm5aco9hqqsq.apps.googleusercontent.com';

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _bounceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _bounceAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bounceAnimationController,
      curve: Curves.elasticOut,
    ));
    
    // Start animations
    _fadeAnimationController.forward();
    _bounceAnimationController.forward();
    
    _initializeGoogleSignIn();
  }

  void _initializeGoogleSignIn() {
    // Initialize Google Sign-In with web support
    final GoogleSignIn googleSignIn = GoogleSignIn.instance;

    unawaited(googleSignIn
        .initialize(clientId: _webClientId, serverClientId: _webClientId)
        .then((_) {
      googleSignIn.authenticationEvents
          .listen(_handleAuthenticationEvent)
          .onError(_handleAuthenticationError);
    }));
  }

  Future<void> _handleAuthenticationEvent(
      GoogleSignInAuthenticationEvent event) async {
    final GoogleSignInAccount? user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    setState(() {
      _currentUser = user;
      _errorMessage = '';
    });

    // If user is signed in, proceed with Supabase authentication
    if (user != null) {
      await _signInToSupabase(user);
    }
  }

  Future<void> _handleAuthenticationError(Object e) async {
    setState(() {
      _currentUser = null;
      _errorMessage = e is GoogleSignInException
          ? _errorMessageFromSignInException(e)
          : 'Unknown error: $e';
    });
  }

  Future<void> _signInToSupabase(GoogleSignInAccount user) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth = await user.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No ID Token found.');
      }

      // Sign in to Supabase with the ID token only
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Welcome to BlaBla!'),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }

    } on AuthException catch (error) {
      if (mounted) {
        _showErrorSnackBar('Authentication error: ${error.message}');
      }
    } catch (error) {
      if (mounted) {
        _showErrorSnackBar('Sign in failed: ${error.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _handleSignIn,
        ),
      ),
    );
  }

Future<void> _handleSignIn() async {
  try {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    if (GoogleSignIn.instance.supportsAuthenticate()) {
      await GoogleSignIn.instance.authenticate();
      // authenticationEvents listener will call _signInToSupabase
    } else if (kIsWeb) {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      unawaited(googleSignIn.initialize(
        clientId: _webClientId,
        serverClientId: _webClientId,
      ).then((_) {
        googleSignIn.authenticationEvents.listen(_handleAuthenticationEvent)
          .onError(_handleAuthenticationError);
        // Attempt lightweight authentication (silent sign-in)
        // googleSignIn.attemptLightweightAuthentication();
      }));
    } else {
      throw Exception('Google Sign-In not supported on this platform');
    }
  } catch (e) {
    setState(() {
      _errorMessage = e.toString();
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  Future<void> _handleSignOut() async {
    try {
      await GoogleSignIn.instance.disconnect();
      await _supabase.auth.signOut();
      setState(() {
        _currentUser = null;
        _errorMessage = '';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.logout, color: Colors.white),
                SizedBox(width: 12),
                Text('Signed out successfully'),
              ],
            ),
            backgroundColor: Colors.grey[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Sign out failed: $e');
    }
  }

  String _errorMessageFromSignInException(GoogleSignInException e) {
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled => 'Sign in canceled',
      _ => 'GoogleSignInException ${e.code}: ${e.description}',
    };
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _bounceAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black,
              Color(0xFF1a1a1a),
              Colors.black,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App Logo/Icon
                        AnimatedBuilder(
                          animation: _bounceAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _bounceAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Colors.white, Colors.grey],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 60,
                                  color: Colors.black,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                        
                        // App Title
                        const Text(
                          'BlaBla',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Subtitle
                        Text(
                          'Connect. Chat. Communicate.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 60),
                        
                        // Main Content
                        if (_currentUser != null) ...[
                          // User Profile Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey[800]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.05),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // User Avatar
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: UserAvatar(
                                    avatarUrl: _currentUser!.photoUrl,
                                    radius: 30,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // User Info
                                Text(
                                  _currentUser!.displayName ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentUser!.email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                
                                // Success message
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16, 
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[900],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        'Successfully signed in!',
                                        style: TextStyle(color: Colors.green),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Sign Out Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _handleSignOut,
                              icon: const Icon(Icons.logout, color: Colors.black),
                              label: const Text(
                                'Sign Out',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ] else ...[
                          // Sign In Section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey[800]!),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Welcome Back!',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[100],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Sign in to continue your conversations',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[400],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),
                                
                                // Sign In Button
                                _isLoading
                                    ? const SizedBox(
                                        height: 56,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _handleSignIn,
                                          icon: Image.network(
                                            'https://developers.google.com/identity/images/g-logo.png',
                                            height: 20,
                                            width: 20,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(Icons.login, color: Colors.black);
                                            },
                                          ),
                                          label: Text(
                                            kIsWeb ? 'Continue with Google' : 'Sign in with Google',
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            elevation: 2,
                                          ),
                                        ),
                                      ),
                                const SizedBox(height: 16),
                                
                                // Platform indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12, 
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    kIsWeb ? 'Web Platform' : 'Mobile Platform',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // Error Message
                        if (_errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red[900],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red[700]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 40),
                        
                        // Footer
                        Text(
                          '© 2024 BlaBla. All rights reserved.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}