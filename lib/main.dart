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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Make sure you actually have this font in assets/fonts/
        // If not, comment this line out to avoid errors.
        fontFamily: 'NotoNaskhArabic',
        useMaterial3: true,
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
  // We use this controller to manage the WebView
  late final WebViewController _webViewController;
  
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  double _progress = 0.0;
  String _currentUrl = 'https://www.google.com';
  
  // Data storage
  List<String> _bookmarks = [];
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _urlController.text = _currentUrl;
    
    // Initialize the WebViewController here (ONCE), not in the build method
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      // ESSENTIAL FOR GMAIL: Set User Agent to look like Safari on iPhone
      ..setUserAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1")
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
            });
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
              _addToHistory(url);
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Web Resource Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  // --- Data Management ---
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
    // Only add if it's not the same as the last entry
    if (_history.isEmpty || _history.last != url) {
      _history.add(url);
      if (_history.length > 50) _history.removeAt(0); // Keep history clean
      await _saveHistory();
    }
  }

  // --- Actions ---

  Future<void> _setupGameCenter() async {
    const gameCenterUrl = 'https://gamecenter.apple.com';
    // Try to launch externally first (for native app), else load in browser
    if (await canLaunchUrl(Uri.parse(gameCenterUrl))) {
      await launchUrl(Uri.parse(gameCenterUrl));
    } else {
      _loadUrl(gameCenterUrl);
    }
  }

  void _loadUrl(String url) {
    String finalUrl = url.trim();
    if (finalUrl.isEmpty) return;
    
    // Basic fix for missing https
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      // Check if it looks like a domain, otherwise search Google
      if (finalUrl.contains('.') && !finalUrl.contains(' ')) {
        finalUrl = 'https://$finalUrl';
      } else {
        // It's a search query
        finalUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(finalUrl)}';
      }
    }
    
    _webViewController.loadRequest(Uri.parse(finalUrl));
    // Keyboard dismiss
    FocusManager.instance.primaryFocus?.unfocus();
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

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App Bar
      appBar: AppBar(
        title: const Text('بڕاوسەری یەکگرتوو'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.gamepad),
            onPressed: _setupGameCenter,
            tooltip: 'گەیم سێنتەر',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
               const PopupMenuItem(
                value: 'bookmarks',
                child: Row(children: [Icon(Icons.bookmark, color: Colors.blue), SizedBox(width: 8), Text('نیشانەکان')]),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(children: [Icon(Icons.history, color: Colors.grey), SizedBox(width: 8), Text('مێژوو')]),
              ),
               const PopupMenuItem(
                value: 'refresh',
                child: Row(children: [Icon(Icons.refresh), SizedBox(width: 8), Text('نوێکردنەوە')]),
              ),
            ],
            onSelected: (value) {
              if (value == 'bookmarks') _showBookmarks();
              else if (value == 'history') _showHistory();
              else if (value == 'refresh') _webViewController.reload();
            },
          ),
        ],
      ),
      
      body: Column(
        children: [
          // Loading Bar
          if (_isLoading)
            LinearProgressIndicator(value: _progress, minHeight: 3),
            
          // URL Bar & Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                 // Home Button
                IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () => _loadUrl('https://www.google.com'),
                ),
                // Back Button
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  onPressed: () async {
                    if (await _webViewController.canGoBack()) {
                      _webViewController.goBack();
                    }
                  },
                ),
                // URL Field
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    textInputAction: TextInputAction.go,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                      hintText: 'گەڕان یان ناونیشان...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _isLoading 
                        ? const SizedBox(width: 15, height: 15, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _urlController.clear(),
                          ),
                    ),
                    onSubmitted: (value) => _loadUrl(value),
                  ),
                ),
                // Forward Button
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  onPressed: () async {
                    if (await _webViewController.canGoForward()) {
                      _webViewController.goForward();
                    }
                  },
                ),
                 // Bookmark Add Button
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: _addBookmark,
                ),
              ],
            ),
          ),
          
          // WebView
          Expanded(
            child: WebViewWidget(controller: _webViewController),
          ),
        ],
      ),
    );
  }

  void _showBookmarks() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نیشانەکان'),
        content: SizedBox(
          width: double.maxFinite,
          child: _bookmarks.isEmpty
              ? const Text('هیچ نیشانەیەک نیە')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _bookmarks.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.bookmark),
                    title: Text(_bookmarks[index], maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
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
        content: SizedBox(
          width: double.maxFinite,
          child: _history.isEmpty
              ? const Text('هیچ مێژویەک نیە')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _history.reversed.toList().length, // Show newest first
                  itemBuilder: (context, index) {
                    final reversedList = _history.reversed.toList();
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(reversedList[index], maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        _loadUrl(reversedList[index]);
                        Navigator.pop(context);
                      },
                    );
                  },
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
            child: const Text('سڕینەوەی هەموو', style: TextStyle(color: Colors.red)),
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