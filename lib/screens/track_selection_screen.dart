import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_text.dart';
import '../widgets/loading.dart';
import '../navigation_helper.dart';

class TrackSelectionScreen extends StatefulWidget {
  const TrackSelectionScreen({super.key});

  @override
  _TrackSelectionScreenState createState() => _TrackSelectionScreenState();
}

class _TrackSelectionScreenState extends State<TrackSelectionScreen> {
  final GlobalKey _imageKey = GlobalKey();
  Uint8List? _overlayImage;
  bool _isLoading = true;
  bool _isChangingLane = false;
  bool _laneChangeComplete = false;
  String? _error;

  // Actual image dimensions
  int? _imgWidth;
  int? _imgHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOverlayImage();
    });
  }

  Future<void> _loadOverlayImage() async {
    try {
      final bytes = await AuthService.instance.captureFrame(overlay: true);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ui.Image info = frame.image;
      setState(() {
        _overlayImage = bytes;
        _imgWidth = info.width;
        _imgHeight = info.height;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load overlay image: $e';
      });
    }
  }

  void _onImageTap(TapDownDetails details) {
    if (_overlayImage == null || _imgWidth == null || _imgHeight == null) {
      return;
    }
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final containerW = box.size.width;
    final containerH = box.size.height;
    final imgW = _imgWidth!.toDouble();
    final imgH = _imgHeight!.toDouble();
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
    if (dx < offsetX ||
        dx > offsetX + displayW ||
        dy < offsetY ||
        dy > offsetY + displayH) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please tap within the image bounds')),
      );
      return;
    }
    final relX = (dx - offsetX) / scale;
    final relY = (dy - offsetY) / scale;

    setState(() {
      _isChangingLane = true;
      _laneChangeComplete = false;
    });

    AuthService.instance
        .chooseLane(relX, relY)
        .then((_) async {
          setState(() {
            _laneChangeComplete = true;
          });
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
      onWillPop:
          () =>
              NavigationHelper.onBackPressed(context, NavScreen.trackSelection),
      child: Scaffold(
        appBar: AppBar(
          leading: NavigationHelper.buildBackArrow(
            context,
            NavScreen.trackSelection,
          ),
          title: GradientText(
            text: "Select Running Track",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            gradient: const LinearGradient(
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
                await AuthService.instance.land();
                await AuthService.instance.endSession(
                  AuthService.instance.sessionId ?? '',
                );
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
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : Column(
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
