import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateChecker extends StatefulWidget {
  final Widget child;

  const UpdateChecker({Key? key, required this.child}) : super(key: key);

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  // IMPORTANT: Replace this URL with the actual URL of your version.json file
  final String _versionUrl =
      'https://raw.githubusercontent.com/ab-h-i-n/bla_bla_chat/main/version.json';

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

        debugPrint(
          'Current version: $currentVersion, Latest version: $latestVersion',
        );

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
          content: Text(
            'A new version ($version) is available. Would you like to update?',
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Later',
                // Use theme color
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Update Now',
                // Use theme color
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                // Pass the version to create a dynamic filename
                _downloadAndInstall(url, version);
              },
            ),
          ],
        );
      },
    );
  }

  /// Initiates the download and shows the progress in a modal bottom sheet.
  Future<void> _downloadAndInstall(String url, String version) async {
    try {
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (BuildContext context) {
          return DownloadProgressSheet(
            downloadStream: OtaUpdate().execute(
              url,
              // Use a dynamic filename based on the version
              destinationFilename: 'app-v$version.apk',
            ),
            onPermissionError: _showPermissionErrorDialog,
          );
        },
      );
    } catch (e) {
      debugPrint('Failed to update. Error: $e');
      _showErrorDialog('Failed to start update: $e');
    }
  }

  /// Shows a dialog when install permissions are denied.
  void _showPermissionErrorDialog() {
    print('Permission error during APK installation.');
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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

  /// Shows a generic error dialog.
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Error'),
        content: Text(message),
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
    return widget.child;
  }
}

//================================================================================
// HELPER WIDGET: DownloadProgressSheet
//================================================================================
class DownloadProgressSheet extends StatefulWidget {
  final Stream<OtaEvent> downloadStream;
  final VoidCallback onPermissionError;

  const DownloadProgressSheet({
    Key? key,
    required this.downloadStream,
    required this.onPermissionError,
  }) : super(key: key);

  @override
  State<DownloadProgressSheet> createState() => _DownloadProgressSheetState();
}

class _DownloadProgressSheetState extends State<DownloadProgressSheet> {
  String _progress = '0';
  String _statusMessage = 'Starting download...';

  @override
  void initState() {
    super.initState();
    widget.downloadStream.listen((OtaEvent event) {
      if (!mounted) return;

      setState(() {
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            _progress = event.value ?? '0';
            _statusMessage = 'Downloading update: $_progress%';
            break;
          case OtaStatus.INSTALLING:
            _statusMessage = 'Download complete. Installing...';
            break;
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            widget.onPermissionError();
            break;
          default:
            debugPrint('OTA Update Status: ${event.status}');
            break;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final double progressValue = (double.tryParse(_progress) ?? 0.0) / 100.0;

    return Container(
      padding: const EdgeInsets.all(24.0),
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Downloading Update',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(_statusMessage),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progressValue,
            minHeight: 8,
          ),
          const SizedBox(height: 10),
          const Text(
            'Please keep the app open.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}