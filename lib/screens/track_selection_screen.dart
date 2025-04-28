import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Internal services and widgets
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';
import '../widgets/loading.dart';
import '../navigation_helper.dart';

/// Screen for selecting the lane on which the drone should follow.
///
/// Fetches an overlay image with lane visualization, displays it,
/// and handles user taps to choose a lane before navigating on.
class TrackSelectionScreen extends StatefulWidget {
  /// Creates the TrackSelection screen widget.
  const TrackSelectionScreen({super.key});

  @override
  _TrackSelectionScreenState createState() => _TrackSelectionScreenState();
}

class _TrackSelectionScreenState extends State<TrackSelectionScreen> {
  /// Key to retrieve the render box of the image container.
  final GlobalKey _imageKey = GlobalKey();

  /// Raw bytes of the overlay image showing lane markings.
  Uint8List? _overlayImage;

  /// Indicates initial loading state for the overlay.
  bool _isLoading = true;

  /// Indicates an ongoing lane-change request.
  bool _isChangingLane = false;

  /// Indicates the confirmation state after lane change succeeds.
  bool _laneChangeComplete = false;

  /// Error message, if any step fails.
  String? _error;

  /// Dimensions of the actual image for coordinate mapping.
  int? _imgWidth;
  int? _imgHeight;

  @override
  void initState() {
    super.initState();
    // Load the overlay image after the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOverlayImage();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Fetches a base64-encoded overlay JPEG from the backend,
  /// decodes it, and records dimensions for hit testing.
  Future<void> _loadOverlayImage() async {
    try {
      final bytes = await AuthService.instance.captureFrame(overlay: true);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _overlayImage = bytes;
        _imgWidth = frame.image.width;
        _imgHeight = frame.image.height;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load overlay image: $e';
      });
    }
  }

  /// Handles tap events on the displayed image.
  /// Computes tap coordinates relative to the original image,
  /// sends chooseLane request, and navigates on success.
  void _onImageTap(TapDownDetails details) {
    if (_overlayImage == null || _imgWidth == null || _imgHeight == null)
      return;

    // Determine the size and position of the image widget on screen
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final containerW = box.size.width;
    final containerH = box.size.height;
    final imgW = _imgWidth!.toDouble();
    final imgH = _imgHeight!.toDouble();
    // Scale to fit while preserving aspect ratio
    final scale =
        (containerW / imgW) < (containerH / imgH)
            ? containerW / imgW
            : containerH / imgH;
    final displayW = imgW * scale;
    final displayH = imgH * scale;
    final offsetX = (containerW - displayW) / 2;
    final offsetY = (containerH - displayH) / 2;
    final dx = local.dx;
    final dy = local.dy;

    // Ensure tap is within the image display bounds
    if (dx < offsetX ||
        dx > offsetX + displayW ||
        dy < offsetY ||
        dy > offsetY + displayH) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please tap within the image bounds')),
      );
      return;
    }

    // Compute relative coordinates back to original image pixels
    final relX = (dx - offsetX) / scale;
    final relY = (dy - offsetY) / scale;

    // Trigger lane change request
    setState(() {
      _isChangingLane = true;
      _laneChangeComplete = false;
    });

    AuthService.instance
        .chooseLane(relX, relY)
        .then((_) async {
          setState(() => _laneChangeComplete = true);
          await Future.delayed(const Duration(seconds: 1));
          Navigator.pushReplacementNamed(context, '/speedSelection');
        })
        .catchError((error) {
          setState(() {
            _error = 'Failed to choose lane: $error';
            _isChangingLane = false;
            _laneChangeComplete = false;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Custom back handling for track selection
      onWillPop:
          () =>
              NavigationHelper.onBackPressed(context, NavScreen.trackSelection),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          leading: NavigationHelper.buildBackArrow(
            context,
            NavScreen.trackSelection,
          ),
          title: const GradientText(
            text: 'Select Running Track',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.blueAccent],
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                // Land, end session, logout, then navigate home
                await AuthService.instance.land();
                if (AuthService.instance.sessionId != null) {
                  await AuthService.instance.endSession(
                    AuthService.instance.sessionId!,
                  );
                }
                await AuthService.instance.logout();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/welcome',
                  (route) => false,
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            // Show loader, error, or the image with instructions
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(child: Text(_error!))
            else
              Column(
                children: [
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Tap on the image to select your lane',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GestureDetector(
                      key: _imageKey,
                      onTapDown: _onImageTap,
                      child: Container(
                        color: Colors.black12,
                        child: Image.memory(
                          _overlayImage!,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            // Overlay during lane-change process
            if (_isChangingLane)
              LoadingWidget(
                text: 'Changing lane...',
                isConfirmed: _laneChangeComplete,
              ),
          ],
        ),
      ),
    );
  }
}
