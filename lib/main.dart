import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بڕاوسەری یەکگرتوو',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'NotoNaskhArabic',
      ),
      home: const BrowserHome(),
    );
  }
}

class BrowserHome extends StatefulWidget {
  const BrowserHome({super.key});

  @override
  _BrowserHomeState createState() => _BrowserHomeState();
}

class _BrowserHomeState extends State<BrowserHome> {
  final TextEditingController _urlController = TextEditingController();
  late WebViewController _webViewController;
  bool _isLoading = true;
  String _currentUrl = 'https://www.google.com';
  List<String> _bookmarks = [];
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _urlController.text = _currentUrl;
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bookmarks = prefs.getStringList('bookmarks') ?? [];
      _history = prefs.getStringList('history') ?? [];
    });
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bookmarks', _bookmarks);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('history', _history);
  }

  Future<void> _addToHistory(String url) async {
    if (!_history.contains(url)) {
      _history.add(url);
      if (_history.length > 50) _history.removeAt(0);
      await _saveHistory();
    }
  }

  Future<void> _setupGameCenter() async {
    const gameCenterUrl = 'https://gamecenter.apple.com';
    
    if (await canLaunchUrl(Uri.parse(gameCenterUrl))) {
      await launchUrl(Uri.parse(gameCenterUrl));
    } else {
      _urlController.text = gameCenterUrl;
      _loadUrl(gameCenterUrl);
    }
  }

  void _loadUrl(String url) {
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }
    
    setState(() {
      _currentUrl = url;
      _isLoading = true;
    });
    
    _webViewController.loadRequest(Uri.parse(url));
    _addToHistory(url);
  }

  void _addBookmark() {
    if (!_bookmarks.contains(_currentUrl)) {
      setState(() {
        _bookmarks.add(_currentUrl);
      });
      _saveBookmarks();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('وێبسایت زیاد کرا بۆ نیشانەکان')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بڕاوسەری یەکگرتوو'),
        actions: [
          IconButton(
            icon: const Icon(Icons.gamepad),
            onPressed: _setupGameCenter,
            tooltip: 'گەیم سێنتەر',
          ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: _addBookmark,
            tooltip: 'زیادکردنی نیشانە',
          ),
          PopupMenuButton<String>(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'bookmarks',
                child: Text('نیشانەکان'),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Text('مێژوو'),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Text('ڕێکخستنەکان'),
              ),
            ],
            onSelected: (value) {
              if (value == 'bookmarks') {
                _showBookmarks();
              } else if (value == 'history') {
                _showHistory();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'ناونیشانی وێب سایت بنووسە',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (value) {
                      _loadUrl(value);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _webViewController.reload();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(
                  controller: WebViewController()
                    ..setJavaScriptMode(JavaScriptMode.unrestricted)
                    ..setBackgroundColor(const Color(0x00000000))
                    ..setNavigationDelegate(
                      NavigationDelegate(
                        onProgress: (int progress) {
                          // بەرەوپێشچوون
                        },
                        onPageStarted: (String url) {
                          setState(() {
                            _isLoading = true;
                            _currentUrl = url;
                            _urlController.text = url;
                          });
                        },
                        onPageFinished: (String url) {
                          setState(() {
                            _isLoading = false;
                          });
                        },
                        onWebResourceError: (WebResourceError error) {
                          // هەڵە
                        },
                        onNavigationRequest: (NavigationRequest request) {
                          // ڕێگەدان بە هەموو وێبسایتێک
                          return NavigationDecision.navigate;
                        },
                      ),
                    )
                    ..loadRequest(Uri.parse(_currentUrl)),
                ),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _loadUrl('https://www.google.com');
        },
        child: const Icon(Icons.home),
        tooltip: 'ماڵەوە',
      ),
    );
  }

  void _showBookmarks() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نیشانەکان'),
        content: _bookmarks.isEmpty
            ? const Text('هیچ نیشانەیەک نیە')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _bookmarks.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(_bookmarks[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _bookmarks.removeAt(index);
                          _saveBookmarks();
                        });
                        Navigator.pop(context);
                        _showBookmarks();
                      },
                    ),
                    onTap: () {
                      _loadUrl(_bookmarks[index]);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('داخستن'),
          ),
        ],
      ),
    );
  }

  void _showHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مێژووی سەردان'),
        content: _history.isEmpty
            ? const Text('هیچ مێژویەک نیە')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _history.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(_history[index]),
                    onTap: () {
                      _loadUrl(_history[index]);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _history.clear();
                _saveHistory();
              });
              Navigator.pop(context);
            },
            child: const Text('سڕینەوەی هەموو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('داخستن'),
          ),
        ],
      ),
    );
  }
}