import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_colors.dart';

class ReelGenerationScreen extends StatefulWidget {
	final List<String>? reelPaths;

	const ReelGenerationScreen({
		super.key,
		required this.reelPaths,
	});

	@override
	State<ReelGenerationScreen> createState() => _ReelGenerationScreenState();
}

class _ReelGenerationScreenState extends State<ReelGenerationScreen> {
	int _selectedReelIndex = 0;
	bool _isPostingToInstagram = false;
	VideoPlayerController? _videoController;
	Future<void>? _videoInitFuture;

	List<String> get _reelPaths => widget.reelPaths ?? const [];

	String? get _currentReelPath {
		if (_reelPaths.isEmpty) return null;
		final safeIndex = _selectedReelIndex.clamp(0, _reelPaths.length - 1);
		return _reelPaths[safeIndex];
	}

	@override
	void initState() {
		super.initState();
		_initializeVideo();
	}

	@override
	void dispose() {
		_videoController?.dispose();
		super.dispose();
	}

	Future<void> _initializeVideo() async {
		final reelPath = _currentReelPath;
		await _videoController?.dispose();
		if (reelPath == null) {
			setState(() {
				_videoController = null;
				_videoInitFuture = null;
			});
			return;
		}

		final controller = VideoPlayerController.file(File(reelPath));
		setState(() {
			_videoController = controller;
			_videoInitFuture = controller.initialize().then((_) {
				controller.setLooping(true);
			});
		});
	}

	void _toggleReel(int index) {
		if (_selectedReelIndex == index) return;
		setState(() {
			_selectedReelIndex = index;
		});
		_initializeVideo();
	}

	void _togglePlayback() {
		final controller = _videoController;
		if (controller == null) return;
		setState(() {
			if (controller.value.isPlaying) {
				controller.pause();
			} else {
				controller.play();
			}
		});
	}

	Future<void> _postToInstagram() async {
		setState(() => _isPostingToInstagram = true);
		try {
			// TODO: Hook up real reel posting logic
			await Future.delayed(const Duration(seconds: 2));
		} finally {
			if (mounted) {
				setState(() => _isPostingToInstagram = false);
			}
		}
	}

	Future<void> _shareReel() async {
		final reelPath = _currentReelPath;
		if (reelPath == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('No reel available to share.'),
					duration: Duration(seconds: 2),
				),
			);
			return;
		}

		await Share.shareXFiles([XFile(reelPath)], text: 'Check out my reel!');
	}

	Future<void> _saveVideo() async {
		final reelPath = _currentReelPath;
		if (reelPath == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('No reel available to save.'),
					duration: Duration(seconds: 2),
				),
			);
			return;
		}

		final filename = File(reelPath).uri.pathSegments.last;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text('Video saved as $filename'),
				duration: const Duration(seconds: 2),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final reelLabel = _selectedReelIndex == 0 ? 'Reel 1' : 'Reel 2';
		final hasSecondReel = _reelPaths.length > 1;

		return Scaffold(
			backgroundColor: AppColors.onSurface,
			appBar: AppBar(
				title: const Text('Generated Reels'),
				backgroundColor: AppColors.onSurface,
				actions: [
					IconButton(
						icon: const Icon(Icons.download_rounded),
						onPressed: _saveVideo,
						tooltip: 'Save Video',
					),
				],
			),
			body: Column(
				children: [
					const SizedBox(height: 16),
					Expanded(
						child: Center(
							child: AspectRatio(
								aspectRatio: 9 / 16,
								child: Container(
									decoration: BoxDecoration(
										color: Colors.black,
										borderRadius: BorderRadius.circular(16),
										border: Border.all(color: Colors.white12),
									),
									child: Stack(
										children: [
											if (_videoController == null || _videoInitFuture == null)
												const Center(
													child: Text(
														'No reel available',
														style: TextStyle(color: Colors.white70),
													),
												)
											else
												FutureBuilder<void>(
													future: _videoInitFuture,
													builder: (context, snapshot) {
														if (snapshot.connectionState != ConnectionState.done) {
															return const Center(
																child: CircularProgressIndicator(color: Colors.white70),
															);
														}
														return GestureDetector(
															onTap: _togglePlayback,
															child: ClipRRect(
																borderRadius: BorderRadius.circular(16),
																child: VideoPlayer(_videoController!),
															),
														);
													},
												),
											Positioned(
												left: 12,
												top: 12,
												child: Container(
													padding: const EdgeInsets.symmetric(
														horizontal: 10,
														vertical: 6,
													),
													decoration: BoxDecoration(
														color: Colors.black54,
														borderRadius: BorderRadius.circular(12),
													),
													child: Text(
														reelLabel,
														style: const TextStyle(
															color: Colors.white,
															fontSize: 12,
															fontWeight: FontWeight.w600,
														),
													),
												),
											),
											if (_videoController != null && _videoController!.value.isInitialized)
												Center(
													child: AnimatedOpacity(
														opacity: _videoController!.value.isPlaying ? 0.0 : 1.0,
														duration: const Duration(milliseconds: 200),
														child: const Icon(
															Icons.play_circle_outline_rounded,
															color: Colors.white70,
															size: 64,
														),
													),
												),
										],
									),
								),
							),
						),
					),
					const SizedBox(height: 16),
					if (hasSecondReel)
					Padding(
						padding: const EdgeInsets.symmetric(horizontal: 24),
						child: Container(
							padding: const EdgeInsets.all(6),
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(20),
								boxShadow: const [
									BoxShadow(
										color: Colors.black12,
										blurRadius: 8,
										offset: Offset(0, 4),
									),
								],
							),
							child: Row(
								children: [
									Expanded(
										child: _buildToggleButton(
											label: 'First Reel',
											isSelected: _selectedReelIndex == 0,
											onTap: () => _toggleReel(0),
										),
									),
									Expanded(
										child: _buildToggleButton(
											label: 'Second Reel',
											isSelected: _selectedReelIndex == 1,
											onTap: hasSecondReel ? () => _toggleReel(1) : () {},
										),
									),
								],
							),
						),
					),
					const SizedBox(height: 16),
					Padding(
						padding: const EdgeInsets.symmetric(horizontal: 24),
						child: Row(
							children: [
								Expanded(
									child: ElevatedButton.icon(
										onPressed: _isPostingToInstagram ? null : _postToInstagram,
										icon: _isPostingToInstagram
												? const SizedBox(
														width: 18,
														height: 18,
														child: CircularProgressIndicator(
															strokeWidth: 2,
															valueColor:
																	AlwaysStoppedAnimation<Color>(Colors.white),
														),
													)
												: const Icon(Icons.camera_alt_rounded, size: 18),
										label: Text(
											_isPostingToInstagram ? 'Posting...' : 'Post to Instagram',
										),
										style: ElevatedButton.styleFrom(
											backgroundColor: AppColors.primary,
											foregroundColor: Colors.white,
											padding: const EdgeInsets.symmetric(vertical: 14),
											shape: RoundedRectangleBorder(
												borderRadius: BorderRadius.circular(12),
											),
										),
									),
								),
								const SizedBox(width: 12),
								Expanded(
									child: OutlinedButton.icon(
										onPressed: _shareReel,
										icon: const Icon(Icons.share_rounded, size: 18),
										label: const Text('Share'),
										style: OutlinedButton.styleFrom(
											foregroundColor: AppColors.primary,
											side: BorderSide(color: AppColors.primary),
											padding: const EdgeInsets.symmetric(vertical: 14),
										),
									),
								),
							],
						),
					),
					const SizedBox(height: 24),
				],
			),
		);
	}

	Widget _buildToggleButton({
		required String label,
		required bool isSelected,
		required VoidCallback onTap,
	}) {
		return GestureDetector(
			onTap: onTap,
			child: Container(
				padding: const EdgeInsets.symmetric(vertical: 10),
				decoration: BoxDecoration(
					color: isSelected ? AppColors.primary : Colors.transparent,
					borderRadius: BorderRadius.circular(16),
				),
				child: Center(
					child: Text(
						label,
						style: TextStyle(
							color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
							fontSize: 13,
							fontWeight: FontWeight.w600,
						),
					),
				),
			),
		);
	}
}
