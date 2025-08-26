import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';

class UpdateChecker extends StatefulWidget {
  final Widget child;

  const UpdateChecker({Key? key, required this.child}) : super(key: key);

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  // IMPORTANT: Replace this URL with the actual URL of your version.json file
  final String _versionUrl = 'https://raw.githubusercontent.com/ab-h-i-n/bla_bla_chat/main/version.json';

  @override
  void initState() {
    super.initState();
    // We only want to check for updates on Android.
    if (Platform.isAndroid) {
      _checkForUpdate();
    }
  }

  /// Checks for a new version of the app on the server.
  Future<void> _checkForUpdate() async {
    try {
      // Get current installed version of the app
      final packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // Fetch the version.json from the server
      final response = await http.get(Uri.parse(_versionUrl));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        String latestVersion = json['version'];
        String apkUrl = json['apk_url'];

        debugPrint('Current version: $currentVersion, Latest version: $latestVersion');

        // Compare the server version with the current installed version
        if (_isNewerVersion(latestVersion, currentVersion)) {
          // If a new version is available, show the update dialog
          _showUpdateDialog(latestVersion, apkUrl);
        }
      }
    } catch (e) {
      // Log any errors during the update check
      debugPrint('Error checking for update: $e');
    }
  }

  /// Compares two version strings (e.g., "1.0.1" > "1.0.0").
  bool _isNewerVersion(String newVersion, String oldVersion) {
    List<int> newParts = newVersion.split('.').map(int.parse).toList();
    List<int> oldParts = oldVersion.split('.').map(int.parse).toList();

    for (var i = 0; i < newParts.length; i++) {
      if (i >= oldParts.length) return true;
      if (newParts[i] > oldParts[i]) return true;
      if (newParts[i] < oldParts[i]) return false;
    }
    return false;
  }

  /// Shows a dialog to the user prompting them to update.
  void _showUpdateDialog(String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must choose an option
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: Text('A new version ($version) is available. Would you like to update?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Later'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Update Now'),
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstall(url);
              },
            ),
          ],
        );
      },
    );
  }

  /// Downloads and initiates the installation of the new APK.
  Future<void> _downloadAndInstall(String url) async {
    try {
      // Use the ota_update package to download and install the new APK
      OtaUpdate().execute(url, destinationFilename: 'bla_bla_chat.apk').listen(
        (OtaEvent event) {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              // Show download progress in a SnackBar
              final progress = event.value ?? '0';
              _showProgressSnackBar('Downloading update: $progress%');
              break;
            case OtaStatus.INSTALLING:
              // Hide the progress SnackBar and show an 'installing' message
              _showProgressSnackBar('Download complete. Installing...');
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              // Show a dialog explaining the permission is needed
              _showPermissionErrorDialog();
              break;
            default:
              // Hide any SnackBars for other statuses
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              break;
          }
        },
      );
    } catch (e) {
      debugPrint('Failed to update. Error: $e');
      _showProgressSnackBar('Error: Failed to start update');
    }
  }

  /// Helper method to show and manage the progress SnackBar.
  void _showProgressSnackBar(String message) {
    // Ensure we are working with a valid context
    if (mounted) {
      // Hide any existing snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // Show the new snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(minutes: 5), // Keep it visible during download
        ),
      );
    }
  }

  /// Helper method to show a dialog when install permissions are denied.
  void _showPermissionErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'To update the app, you must allow installing from unknown sources in your phone\'s settings.',
        ),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This widget just wraps the child, the magic happens in initState
    return widget.child;
  }
}