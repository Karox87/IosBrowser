import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;
import 'dart:io' show Platform;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
  State<BrowserHome> createState() => _BrowserHomeState();
}

class _BrowserHomeState extends State<BrowserHome> {
  InAppWebViewController? webViewController;
  final TextEditingController _urlController = TextEditingController();
  bool _isDraggingPath = false;
  bool _isLoading = false;
  double _progress = 0.0;
  String _currentUrl = 'https://www.google.com';
  String _currentViewMode = 'Desktop';
  bool canGoBack = false;
  bool canGoForward = false;
  
  List<String> _bookmarks = [];
  List<String> _history = [];

  // Aim Assist State
  bool _isMenuOpen = false;
  bool _showAimAssist = true;
  bool _showAppBar = true;
  Offset _pivotPoint = const Offset(150, 500);
  double _lineLength = 100.0;
  double _allCircleSize = 20.0;
  double _pathOpacity = 0.5;
  Color _activeColor = Colors.white;
  double _currentAngle = -0.8;
  double _zoomLevel = 1.0; // زیادکردنی zoom
double _lineThickness = 2.0; // تۆخی هێڵ
  // Store popup controllers
  final Map<int, InAppWebViewController> _popupControllers = {};
  
  // User Agents
  final String iphoneUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1";
  final String ipadUA = "Mozilla/5.0 (iPad; CPU OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1";
  final String desktopUA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

  @override
  void initState() {
    super.initState();
    _loadData();
    _urlController.text = _currentUrl;
    _requestPermissions();
  }

  // Request all necessary permissions
  Future<void> _requestPermissions() async {
    try {
      await [
        Permission.camera,
        Permission.microphone,
        Permission.location,
        Permission.storage,
      ].request();
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
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
    if (_history.isEmpty || _history.last != url) {
      _history.add(url);
      if (_history.length > 50) _history.removeAt(0);
      await _saveHistory();
    }
  }

void _loadUrl(String url) {
  String finalUrl = url.trim();
  if (finalUrl.isEmpty) return;
  
  if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
    if (finalUrl.contains('.') && !finalUrl.contains(' ')) {
      finalUrl = 'https://$finalUrl';
    } else {
      finalUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(finalUrl)}';
    }
  }
  
  // زیادکردنی Headers بۆ خۆڕاگرتن لە وەک براوسەری ڕاستەقینە
  webViewController?.loadUrl(
    urlRequest: URLRequest(
      url: WebUri(finalUrl),
      headers: {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Cache-Control': 'max-age=0',
      },
    ),
  );
  
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

  Future<void> _switchViewMode(String mode) async {
    String newUserAgent;

    switch (mode) {
      case 'iPad':
        newUserAgent = ipadUA;
        break;
      case 'Desktop':
        newUserAgent = desktopUA;
        break;
      case 'iPhone':
      default:
        newUserAgent = iphoneUA;
        break;
    }

    await webViewController?.setSettings(
      settings: InAppWebViewSettings(userAgent: newUserAgent)
    );
    await webViewController?.reload();
    
    setState(() {
      _currentViewMode = mode;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جۆری دیمەن گۆڕدرا بۆ $mode')),
      );
    }
  }

  Future<void> _openInExternalBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

InAppWebViewSettings _getWebViewSettings() {
  // بەپێی _currentViewMode UA دیاری بکە
  String selectedUA;
  UserPreferredContentMode contentMode;
  
  switch (_currentViewMode) {
    case 'iPhone':
      selectedUA = iphoneUA;
      contentMode = UserPreferredContentMode.MOBILE;
      break;
    case 'iPad':
      selectedUA = ipadUA;
      contentMode = UserPreferredContentMode.MOBILE;
      break;
    case 'Desktop':
    default:
      selectedUA = desktopUA;
      contentMode = UserPreferredContentMode.DESKTOP;
      break;
  }
  
  return InAppWebViewSettings(
    javaScriptEnabled: true,
    domStorageEnabled: true,
    databaseEnabled: true,
    allowsInlineMediaPlayback: true,
    mediaPlaybackRequiresUserGesture: false,
    javaScriptCanOpenWindowsAutomatically: true,
    supportMultipleWindows: true,
    cacheEnabled: true,
    clearCache: false,
    thirdPartyCookiesEnabled: true,
    sharedCookiesEnabled: Platform.isIOS,
    
    userAgent: selectedUA,
    applicationNameForUserAgent: "",
    
    useShouldOverrideUrlLoading: false,
    geolocationEnabled: true,
    transparentBackground: false,
    useHybridComposition: Platform.isAndroid,
    mixedContentMode: Platform.isAndroid ? MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW : null,
    builtInZoomControls: false,
    displayZoomControls: false,
    limitsNavigationsToAppBoundDomains: false,
    allowsBackForwardNavigationGestures: Platform.isIOS,
    suppressesIncrementalRendering: false,
    allowsLinkPreview: false,
    allowingReadAccessTo: Platform.isIOS ? WebUri("https://") : null,
    allowFileAccessFromFileURLs: true,
    allowUniversalAccessFromFileURLs: true,
    verticalScrollBarEnabled: true,
    horizontalScrollBarEnabled: true,
    disableContextMenu: false,
    useWideViewPort: true,
    loadWithOverviewMode: true,
    allowContentAccess: true,
    allowFileAccess: true,
    incognito: false,
    textZoom: (_zoomLevel * 100).toInt(),  // زووم لێرە زیاد کرا
    preferredContentMode: contentMode,
  );
}
  String _getPopupBridgeScript() {
    return """
      (function() {
        const originalOpen = window.open;
        window.open = function(url, name, features) {
          console.log('Opening popup:', url);
          return originalOpen.call(this, url, name, features);
        };
        
        window.addEventListener('message', function(event) {
          console.log('Received message:', event.data);
        }, false);
        
        if (window.opener && !window.opener.closed) {
          window.addEventListener('load', function() {
            try {
              window.opener.postMessage({
                type: 'popup-ready',
                url: window.location.href
              }, '*');
            } catch(e) {
              console.log('Could not notify opener:', e);
            }
          });
        }
      })();
    """;
  }

  // فەنکشن بۆ دیاریکردنی چوارگۆشەی ڕێڕەوەکە
Rect _calculatePathRect(Offset middle, Offset pivot, Offset end, double pathWidth) {
  final pathAngle = math.atan2(end.dy - pivot.dy, end.dx - pivot.dx);
  final pathLength = (end - pivot).distance;
  
  // دروستکردنی گۆڕاوی Path
  final path = Path()
    ..moveTo(pivot.dx, pivot.dy - pathWidth / 2)
    ..lineTo(pivot.dx + pathLength * math.cos(pathAngle), 
             pivot.dy + pathLength * math.sin(pathAngle) - pathWidth / 2)
    ..lineTo(pivot.dx + pathLength * math.cos(pathAngle), 
             pivot.dy + pathLength * math.sin(pathAngle) + pathWidth / 2)
    ..lineTo(pivot.dx, pivot.dy + pathWidth / 2)
    ..close();
    
  return path.getBounds();
}

// فەنکشن بۆ دیاریکردنی ئایا خاڵ لە ڕێڕەوەکەدایە
bool _isPointInPath(Offset point, Offset middle, Offset pivot, Offset end, double pathWidth) {
  final pathAngle = math.atan2(end.dy - pivot.dy, end.dx - pivot.dx);
  final pathLength = (end - pivot).distance;
  
  // گۆڕینی خاڵ بۆ سیستەمی ڕاستەوخۆی ڕێڕەوەکە
  final translatedPoint = Offset(
    point.dx - pivot.dx,
    point.dy - pivot.dy,
  );
  
  // سووڕانەوەی خاڵ بەپێی گۆشەکە
  final rotatedPoint = Offset(
    translatedPoint.dx * math.cos(-pathAngle) - translatedPoint.dy * math.sin(-pathAngle),
    translatedPoint.dx * math.sin(-pathAngle) + translatedPoint.dy * math.cos(-pathAngle),
  );
  
  // چێککردن بۆ ئەوەی ئایا خاڵ لە ناوچەی ڕێڕەوەکەدایە
  return rotatedPoint.dx >= 0 && 
         rotatedPoint.dx <= pathLength && 
         rotatedPoint.dy.abs() <= pathWidth / 2;
}

  @override
  Widget build(BuildContext context) {
    Offset middlePoint = _pivotPoint; 
    double gap = _allCircleSize * 2.1;
    Offset pivotPoint = middlePoint + Offset.fromDirection(_currentAngle + math.pi, gap);
    Offset endPoint = middlePoint + Offset.fromDirection(_currentAngle, _lineLength);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _showAppBar ? AppBar(
        backgroundColor: Colors.black87,
        title: const Text('بڕاوسەری یەکگرتوو', style: TextStyle(color: Colors.white)),
        elevation: 1,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'bookmarks',
                child: Row(children: [
                  Icon(Icons.bookmark, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('نیشانەکان')
                ]),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(children: [
                  Icon(Icons.history, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('مێژوو')
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'جۆری دیمەن',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'viewmode_iphone',
                child: Row(children: [
                  Icon(
                    Icons.phone_iphone,
                    color: _currentViewMode == 'iPhone' ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text('iPhone'),
                  if (_currentViewMode == 'iPhone')
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.check, color: Colors.blue, size: 18),
                    ),
                ]),
              ),
              PopupMenuItem(
                value: 'viewmode_ipad',
                child: Row(children: [
                  Icon(
                    Icons.tablet_mac,
                    color: _currentViewMode == 'iPad' ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text('iPad'),
                  if (_currentViewMode == 'iPad')
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.check, color: Colors.blue, size: 18),
                    ),
                ]),
              ),
              PopupMenuItem(
                value: 'viewmode_desktop',
                child: Row(children: [
                  Icon(
                    Icons.computer,
                    color: _currentViewMode == 'Desktop' ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text('Desktop'),
                  if (_currentViewMode == 'Desktop')
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.check, color: Colors.blue, size: 18),
                    ),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'open_external',
                child: Row(children: [
                  Icon(Icons.open_in_browser, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('کردنەوە لە بڕاوسەری دەرەکی')
                ]),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(children: [
                  Icon(Icons.refresh),
                  SizedBox(width: 8),
                  Text('نوێکردنەوە')
                ]),
              ),
            ],
            onSelected: (value) {
              if (value == 'bookmarks') {
                _showBookmarks();
              } else if (value == 'history') {
                _showHistory();
              } else if (value == 'refresh') {
                webViewController?.reload();
              } else if (value == 'viewmode_iphone') {
                _switchViewMode('iPhone');
              } else if (value == 'viewmode_ipad') {
                _switchViewMode('iPad');
              } else if (value == 'viewmode_desktop') {
                _switchViewMode('Desktop');
              } else if (value == 'open_external') {
                _openInExternalBrowser(_currentUrl);
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              if (_progress < 1.0 && _isLoading)
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.home, color: Colors.white, size: 20),
                      onPressed: () => _loadUrl('https://www.google.com'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.white),
                      onPressed: canGoBack ? () => webViewController?.goBack() : null,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        textInputAction: TextInputAction.go,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                          hintText: 'گەڕان یان ناونیشان...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          filled: true,
                          fillColor: Colors.grey[900],
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: _isLoading 
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                onPressed: () => _urlController.clear(),
                              ),
                        ),
                        onSubmitted: (value) => _loadUrl(value),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white),
                      onPressed: canGoForward ? () => webViewController?.goForward() : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_border, color: Colors.white),
                      onPressed: _addBookmark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ) : null,
      body: Stack(
        children: [
          // BROWSER LAYER
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_currentUrl)),
            initialSettings: _getWebViewSettings(),
            onWebViewCreated: (controller) async {
              webViewController = controller;
              
              await controller.evaluateJavascript(source: """
                (function() {
                  delete window._flutter_inappwebview;
                  delete window.flutter_inappwebview;
                  delete window.flutter;
                  
                  Object.defineProperty(navigator, 'webdriver', {
                    get: () => false,
                    configurable: true
                  });
                  
                  window.chrome = {
                    runtime: {},
                    loadTimes: function() {},
                    csi: function() {},
                    app: {}
                  };
                  
                  const originalPlatform = navigator.platform;
                  Object.defineProperty(navigator, 'platform', {
                    get: () => originalPlatform || 'Win32',
                    configurable: true
                  });
                  
                  Object.defineProperty(navigator, 'plugins', {
                    get: () => [1, 2, 3, 4, 5],
                    configurable: true
                  });
                  
                  Object.defineProperty(navigator, 'languages', {
                    get: () => ['en-US', 'en', 'ku'],
                    configurable: true
                  });
                  
                  Object.defineProperty(navigator, 'maxTouchPoints', {
                    get: () => 5,
                    configurable: true
                  });
                  
                  // Override getUserMedia to prevent camera errors
                  if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                    const originalGetUserMedia = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
                    navigator.mediaDevices.getUserMedia = function(constraints) {
                      console.log('getUserMedia called with:', constraints);
                      return originalGetUserMedia(constraints).catch(err => {
                        console.log('getUserMedia error (suppressed):', err);
                        return Promise.reject(err);
                      });
                    };
                  }
                })();
                
                ${_getPopupBridgeScript()}
              """);
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
                _currentUrl = url.toString();
                _urlController.text = _currentUrl;
              });
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
                _currentUrl = url.toString();
                _urlController.text = _currentUrl;
              });
              
              _addToHistory(_currentUrl);
              canGoBack = await controller.canGoBack();
              canGoForward = await controller.canGoForward();
              setState(() {});
              
              await controller.evaluateJavascript(source: _getPopupBridgeScript());
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
            onCreateWindow: (controller, createWindowAction) async {
              try {
                if (!mounted) return false;
                
                final requestUrl = createWindowAction.request.url?.toString() ?? '';
                final windowId = createWindowAction.windowId;
                
                debugPrint('Creating window for: $requestUrl');
                
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) {
                    return Dialog(
                      backgroundColor: Colors.black,
                      insetPadding: const EdgeInsets.all(10),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.95,
                        height: MediaQuery.of(context).size.height * 0.85,
                        child: Column(
                          children: [
                            Container(
                              color: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () {
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                    },
                                  ),
                                  const Expanded(
                                    child: Text(
                                      "پەنجەرەی لۆگین",
                                      style: TextStyle(color: Colors.white, fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 48),
                                ],
                              ),
                            ),
                            Expanded(
                              child: InAppWebView(
                                windowId: windowId,
                                initialSettings: _getWebViewSettings(),
                                onWebViewCreated: (popupController) async {
                                  _popupControllers[windowId] = popupController;
                                                                  
                                  await controller.evaluateJavascript(source: """
  (function() {
    // Override fetch to add headers
    const originalFetch = window.fetch;
    window.fetch = function(...args) {
      if (args[1]) {
        args[1].headers = {
          ...args[1].headers,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
        };
      }
      return originalFetch.apply(this, args);
    };
  })();
""");
                                },
                                onLoadStop: (popupController, url) async {
                                  debugPrint('Popup loaded: ${url?.toString()}');
                                  
                                  if (url != null) {
                                    final urlString = url.toString();
                                    
                                    // Check for successful OAuth
                                    if (urlString.contains('code=') || 
                                        urlString.contains('access_token=') ||
                                        (!urlString.contains('accounts.google.com') &&
                                         !urlString.contains('oauth') &&
                                         !urlString.contains('login') &&
                                         !urlString.contains('signin') &&
                                         !urlString.contains('auth/handler') &&
                                         !urlString.contains('firebaseapp.com'))) {
                                      
                                      debugPrint('OAuth completed successfully');
                                      await Future.delayed(const Duration(milliseconds: 1000));
                                      
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                      
                                      await Future.delayed(const Duration(milliseconds: 300));
                                      webViewController?.reload();
                                      
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('لۆگین سەرکەوتوو بوو! ✓'),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                onCloseWindow: (popupController) {
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                  _popupControllers.remove(windowId);
                                                                },
                                onConsoleMessage: (popupController, consoleMessage) {
                                  // Suppress camera errors in popup
                                  if (!consoleMessage.message.contains('camera') &&
                                      !consoleMessage.message.contains('Camera')) {
                                    debugPrint('Popup: ${consoleMessage.message}');
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
                
                return true;
              } catch (e) {
                debugPrint("Error opening popup: $e");
                return false;
              }
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              return NavigationActionPolicy.ALLOW;
            },
            onPermissionRequest: (controller, request) async {
              // Grant all permissions except camera/microphone if not needed
              return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT,
              );
            },
            onConsoleMessage: (controller, consoleMessage) {
              // Suppress camera-related errors
              if (!consoleMessage.message.contains('camera') &&
                  !consoleMessage.message.contains('Camera') &&
                  !consoleMessage.message.contains('VideoCapture')) {
                debugPrint('Console: ${consoleMessage.message}');
              }
            },
          ),

          // AIM ASSIST LAYER
// AIM ASSIST LAYER
if (_showAimAssist) ...[
  Positioned.fill(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: ProAimPainter(
            pivot: pivotPoint, 
            middle: middlePoint,
            end: endPoint,
            radius: _allCircleSize,
            pathWidth: _allCircleSize * 1.9,
            opacity: _pathOpacity,
            color: _activeColor,
            lineThickness: _lineThickness,
          ),
        ),
      ),
    ),
  ),

  // DRAG HANDLE لە نێوان pivot و middle
  Positioned(
    left: (pivotPoint.dx + middlePoint.dx) / 2 - 20,
    top: (pivotPoint.dy + middlePoint.dy) / 2 - 20,
 child: GestureDetector(
  behavior: HitTestBehavior.opaque,
  onPanStart: (_) {},
  onPanUpdate: (details) {
    setState(() {
      _pivotPoint += details.delta;
    });
  },
      child: Container(
        width: 40,
        height: 40,
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _activeColor.withOpacity(0.0),
            ),
          ),
        ),
      ),
    ),
  ),
  
  // DRAG HANDLE لە نێوان middle و end
  Positioned(
    left: (middlePoint.dx + endPoint.dx) / 2 - 20,
    top: (middlePoint.dy + endPoint.dy) / 2 - 20,
    child: GestureDetector(
  behavior: HitTestBehavior.opaque,
  onPanStart: (_) {},
  onPanUpdate: (details) {
    setState(() {
      _pivotPoint += details.delta;
    });
  },
      child: Container(
        width: 40,
        height: 40,
        color: const Color.fromARGB(0, 0, 0, 0),
        child: Center(
          child: Container(
            width: 15,
            height: 15,
            
            decoration: BoxDecoration(
              
              shape: BoxShape.circle,
              color: _activeColor.withOpacity(0.1),
            ),
          ),
        ),
      ),
    ),
  ),
  
  // END POINT HANDLE
  // END POINT HANDLE - ناوچەی گرتنی جیا و گەورەتر
  Positioned(
    left: endPoint.dx - 30, // قەبارەی جیاکراوی 60x60
    top: endPoint.dy - 30,
   child: GestureDetector(
  behavior: HitTestBehavior.opaque,
  onPanStart: (_) {},
  onPanUpdate: (details) {
    setState(() {
      Offset newEnd = endPoint + details.delta;
          _lineLength = (newEnd - middlePoint).distance;
          
          _currentAngle = math.atan2(
            newEnd.dy - middlePoint.dy, 
            newEnd.dx - middlePoint.dx
          );

          double gap = _allCircleSize * 2.1;
          if (_lineLength < gap + 20) _lineLength = gap + 20;
        });
      },
      child: Container(
        width: 60, // قەبارەی جیا کە ناگۆڕێت
        height: 60,
        color: const Color.fromARGB(0, 0, 0, 0),
        child: Center(
          child: Container(
            width: _allCircleSize * 1.5,
            height: _allCircleSize * 1.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _activeColor.withOpacity(0.0),
              border: Border.all(color: _activeColor, width: 2),
            ),
          ),
        ),
      ),
    ),
  ),
],

          // SETTINGS BUTTON
          Positioned(
            right: 10, 
            top: _showAppBar ? 10 : MediaQuery.of(context).padding.top + 10,
            child: FloatingActionButton.small(
              backgroundColor: _activeColor.withOpacity(0.5),
              child: const Icon(Icons.tune, color: Colors.white, size: 18),
              onPressed: () => setState(() => _isMenuOpen = !_isMenuOpen),
            ),
          ),

          if (_isMenuOpen) _buildSettings(),
        ],
      ),
    );
  }

Widget _buildHandle(Offset pos, double r, Function(Offset) onMove) {
  return Positioned(
    left: pos.dx - (r + 15),
    top: pos.dy - (r + 15),
    child: GestureDetector(
      onPanUpdate: (details) => onMove(details.delta),
      child: Container(
        width: (r + 15) * 2,
        height: (r + 15) * 2,
        color: Colors.transparent,
      ),
    ),
  );
}

Widget _buildSettings() {
  return Center(
    child: Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _activeColor, width: 2),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "ڕێکخستنەکان",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(color: Colors.white24),
            
            SwitchListTile(
              title: const Text("پیشاندانی Aim Assist", style: TextStyle(fontSize: 13, color: Colors.white)),
              value: _showAimAssist,
              activeThumbColor: _activeColor,
              onChanged: (val) => setState(() => _showAimAssist = val),
            ),
            
            SwitchListTile(
              title: const Text("پیشاندانی Navigation Bar", style: TextStyle(fontSize: 13, color: Colors.white)),
              value: _showAppBar,
              activeThumbColor: _activeColor,
              onChanged: (val) => setState(() => _showAppBar = val),
            ),
            
            if (_showAimAssist) ...[
              _slider("قەبارەی گشتی", _allCircleSize / 100, (v) => setState(() => _allCircleSize = v * 100), 0.05, 1.0),
              _slider("ڕوونی ڕێڕەو", _pathOpacity, (v) => setState(() => _pathOpacity = v), 0.1, 1.0),
              _slider("تۆخی هێڵ", _lineThickness / 10, (v) => setState(() => _lineThickness = v * 10), 0.1, 1.0),
              
              const SizedBox(height: 10),
              const Text("ڕەنگ:", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Colors.white,
                  Colors.red,
                  Colors.green,
                  Colors.cyan,
                  Colors.yellow,
                  Colors.purple,
                ].map((c) => GestureDetector(
                  onTap: () => setState(() => _activeColor = c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: _activeColor == c ? 2.5 : 0,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],
            
            const SizedBox(height: 15),
            const Divider(color: Colors.white24),
            const Text("زووم:", style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_zoomLevel > 0.5) _zoomLevel -= 0.1;
                      webViewController?.setSettings(
                        settings: _getWebViewSettings(),
                      );
                    });
                  },
                  icon: const Icon(Icons.zoom_out, color: Colors.white),
                  tooltip: 'زووم ئاوت',
                ),
                Text(
                  '${(_zoomLevel * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_zoomLevel < 3.0) _zoomLevel += 0.1;
                      webViewController?.setSettings(
                        settings: _getWebViewSettings(),
                      );
                    });
                  },
                  icon: const Icon(Icons.zoom_in, color: Colors.white),
                  tooltip: 'زووم ئین',
                ),
              ],
            ),
            
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () => setState(() => _isMenuOpen = false),
              style: ElevatedButton.styleFrom(
                backgroundColor: _activeColor,
                foregroundColor: Colors.black,
              ),
              child: const Text("داخستن", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _slider(String label, double val, Function(double) onChanged, double min, double max) {
return Column(
children: [
Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
Slider(
value: val,
min: min,
max: max,
activeColor: _activeColor,
onChanged: onChanged,
),
],
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
? const Text('هیچ نیشانەیەک نییە')
: ListView.builder(
shrinkWrap: true,
itemCount: _bookmarks.length,
itemBuilder: (context, index) => ListTile(
leading: const Icon(Icons.bookmark),
title: Text(
_bookmarks[index],
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
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
? const Text('هیچ مێژوویەک نییە')
: ListView.builder(
shrinkWrap: true,
itemCount: _history.reversed.toList().length,
itemBuilder: (context, index) {
final reversedList = _history.reversed.toList();
return ListTile(
leading: const Icon(Icons.history),
title: Text(
reversedList[index],
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
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
child: const Text(
'سڕینەوەی هەموو',
style: TextStyle(color: Colors.red),
),
),
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('داخستن'),
),
],
),
);
}
@override
void dispose() {
_urlController.dispose();
_popupControllers.clear();
super.dispose();
}


}




class ProAimPainter extends CustomPainter {
  final Offset pivot, middle, end;
  final double radius, pathWidth, opacity;
  final Color color;
  final double lineThickness;
  
  ProAimPainter({
    required this.pivot,
    required this.middle,
    required this.end,
    required this.radius,
    required this.pathWidth,
    required this.opacity,
    required this.color,
    required this.lineThickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double angle = math.atan2(end.dy - pivot.dy, end.dx - pivot.dx);
    double dist = (end - pivot).distance;
    
    // باکگراوندی کاپاسیتی (ڕوونی ڕێڕەو)
    final pathPaint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromLTRBR(0, -pathWidth / 2, dist, pathWidth / 2, Radius.circular(radius)),
      pathPaint,
    );

    // هێڵی ناوەڕاست بە شێوەی بچربچر (dashed)
    final innerLinePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = lineThickness
      ..strokeCap = StrokeCap.round;

    // کێشانی هێڵی dashed
    _drawDashedLine(canvas, const Offset(0, 0), Offset(dist, 0), innerLinePaint);
    
    canvas.restore();

    // کێشانی بازنەکان بە هێڵی بچربچر
    _drawDashedCircle(canvas, pivot, radius, lineThickness);
    _drawDashedCircle(canvas, middle, radius, lineThickness);
    _drawCircle(canvas, end, radius, lineThickness);
  }

  // فەنکشنی نوێ بۆ کێشانی dashed line
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 4.0;
    double distance = (end - start).distance;
    
    double dashCount = (distance / (dashWidth + dashSpace)).floorToDouble();
    
    for (int i = 0; i < dashCount; i++) {
      double startX = start.dx + (i * (dashWidth + dashSpace));
      double endX = startX + dashWidth;
      
      if (endX > end.dx) endX = end.dx;
      
      canvas.drawLine(
        Offset(startX, start.dy),
        Offset(endX, end.dy),
        paint,
      );
    }
  }

  // فەنکشنی نوێ بۆ کێشانی بازنەی بچربچر (pivot و middle)
  void _drawDashedCircle(Canvas canvas, Offset center, double r, double strokeWidth) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const dashAngle = 0.2; // قەبارەی هەر بچرێک
    const gapAngle = 0.15;  // بۆشایی نێوان بچرەکان
    
    double currentAngle = 0.0;
    while (currentAngle < math.pi * 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        currentAngle,
        dashAngle,
        false,
        paint,
      );
      currentAngle += dashAngle + gapAngle;
    }
    
    // خاڵی ناوەڕاست
    canvas.drawCircle(center, 1, paint..style = PaintingStyle.fill);
  }

  // بازنەی ئاسایی بۆ end point
  void _drawCircle(Canvas canvas, Offset center, double r, double strokeWidth) {
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, r, p);
    canvas.drawCircle(center, 1, p..style = PaintingStyle.fill);
  }

  @override
bool shouldRepaint(covariant ProAimPainter oldDelegate) {
  return pivot != oldDelegate.pivot ||
         middle != oldDelegate.middle ||
         end != oldDelegate.end ||
         radius != oldDelegate.radius ||
         pathWidth != oldDelegate.pathWidth ||
         opacity != oldDelegate.opacity ||
         color != oldDelegate.color ||
         lineThickness != oldDelegate.lineThickness;
}
}

