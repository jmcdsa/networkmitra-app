import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'api.dart';
import 'chat.dart' show asList;
import 'upgrade.dart';
import 'widgets.dart';

/// Experience videos shared inside my own company. Everybody can watch, Pro users can post.
class VideosTab extends StatefulWidget {
  const VideosTab({super.key});
  @override
  State<VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends State<VideosTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> items = [];
  bool loading = true, more = true, loadingMore = false;
  String? error;
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('videos');
      items = asList(d['items']);
      more = items.length >= 15;
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadMore() async {
    if (!more || loadingMore || items.isEmpty) return;
    loadingMore = true;
    try {
      final d = await Api.get('videos?before=${items.last['id']}');
      final n = asList(d['items']);
      items.addAll(n);
      more = n.length >= 15;
      if (mounted) setState(() {});
    } catch (_) {}
    loadingMore = false;
  }

  Future<void> _post() async {
    if (!featureOn('video_post')) {
      goUpgrade(context, 'Sharing your own videos is available on the Pro plan. Everybody can watch.');
      return;
    }
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const PostVideoScreen()));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(controller: _scroll, padding: const EdgeInsets.all(12), children: [
        Row(children: [
          const Expanded(child: Text('Experience videos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          FilledButton.icon(onPressed: _post, icon: const Icon(Icons.videocam), label: const Text('Share')),
        ]),
        const SizedBox(height: 4),
        const Text('Short videos from people in your company: success stories, product experience, tips.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 8),
        if (items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No videos yet. Be the first to share your experience.'))),
        for (final v in items)
          VideoCard(
            key: ValueKey(v['id']),
            v: v,
            onDeleted: () => setState(() => items.removeWhere((e) => e['id'] == v['id'])),
          ),
        if (loadingMore) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}

class VideoCard extends StatefulWidget {
  final Map<String, dynamic> v;
  final VoidCallback onDeleted;
  const VideoCard({super.key, required this.v, required this.onDeleted});
  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  VideoPlayerController? c;
  bool starting = false, failed = false;
  late bool liked = widget.v['liked'] == true;
  late int likes = (widget.v['likes'] as int?) ?? 0;

  @override
  void dispose() {
    c?.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (c != null) {
      c!.value.isPlaying ? await c!.pause() : await c!.play();
      setState(() {});
      return;
    }
    setState(() {
      starting = true;
      failed = false;
    });
    try {
      final ctl = VideoPlayerController.networkUrl(Uri.parse(widget.v['url'].toString()));
      await ctl.initialize();
      ctl.setLooping(false);
      ctl.addListener(() {
        if (mounted) setState(() {});
      });
      c = ctl;
      await ctl.play();
    } catch (_) {
      failed = true;
    }
    if (mounted) setState(() => starting = false);
  }

  Future<void> _like() async {
    try {
      final d = await Api.post('videos/${widget.v['id']}/like', {});
      if (mounted) {
        setState(() {
          liked = d['liked'] == true;
          likes = (d['likes'] as int?) ?? likes;
        });
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this video?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await Api.delete('videos/${widget.v['id']}');
      widget.onDeleted();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = c?.value.isPlaying ?? false;
    final ready = c != null && c!.value.isInitialized;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: _play,
          child: AspectRatio(
            aspectRatio: ready ? c!.value.aspectRatio : 16 / 9,
            child: Stack(alignment: Alignment.center, children: [
              Container(color: Colors.black),
              if (ready) VideoPlayer(c!),
              if (starting) const CircularProgressIndicator(color: Colors.white),
              if (failed) const Text('Could not play this video.', style: TextStyle(color: Colors.white)),
              if (!starting && !playing && !failed) const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
              if (ready) Positioned(left: 0, right: 0, bottom: 0, child: VideoProgressIndicator(c!, allowScrubbing: true, padding: const EdgeInsets.only(top: 6))),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.v['title'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('by ${widget.v['author']}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (widget.v['caption'].toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(widget.v['caption'].toString())),
          ]),
        ),
        Row(children: [
          TextButton.icon(
            onPressed: _like,
            icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.red : null),
            label: Text('$likes'),
          ),
          const Spacer(),
          if (widget.v['mine'] == true) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ]),
      ]),
    );
  }
}

class PostVideoScreen extends StatefulWidget {
  const PostVideoScreen({super.key});
  @override
  State<PostVideoScreen> createState() => _PostVideoScreenState();
}

class _PostVideoScreenState extends State<PostVideoScreen> {
  final title = TextEditingController();
  final caption = TextEditingController();
  XFile? file;
  bool busy = false;

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickVideo(source: src, maxDuration: const Duration(seconds: 90));
      if (x != null) setState(() => file = x);
    } catch (_) {
      if (mounted) toast(context, 'Could not open the video.');
    }
  }

  Future<void> _send() async {
    if (file == null) {
      toast(context, 'Choose a video first.');
      return;
    }
    if (title.text.trim().isEmpty) {
      toast(context, 'Write a title.');
      return;
    }
    setState(() => busy = true);
    try {
      await Api.upload('videos', 'video', file!.path, fields: {'title': title.text.trim(), 'caption': caption.text.trim()});
      if (mounted) {
        toast(context, 'Your video is shared.');
        Navigator.pop(context, true);
      }
      return;
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share a video')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 10, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: busy ? null : () => _pick(ImageSource.gallery), icon: const Icon(Icons.video_library), label: const Text('From gallery')),
          OutlinedButton.icon(onPressed: busy ? null : () => _pick(ImageSource.camera), icon: const Icon(Icons.videocam), label: const Text('Record now')),
        ]),
        const SizedBox(height: 8),
        Text(file == null ? 'No video chosen yet. Up to about 1 minute works best.' : 'Chosen: ${file!.name}', style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
        TextField(controller: title, maxLength: 80, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: caption, maxLength: 500, maxLines: 4, decoration: const InputDecoration(labelText: 'Tell your experience (optional)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        FilledButton(onPressed: busy ? null : _send, child: Text(busy ? 'Uploading... please wait' : 'Share video')),
        const SizedBox(height: 8),
        const Text('Only people of your own company can see this video. Please share only your own honest experience.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
    );
  }
}
