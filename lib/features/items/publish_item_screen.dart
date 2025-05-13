import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/vision_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class PublishItemScreen extends ConsumerStatefulWidget {
  const PublishItemScreen({super.key});

  @override
  ConsumerState<PublishItemScreen> createState() => _PublishItemScreenState();
}

class _PublishItemScreenState extends ConsumerState<PublishItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _estimatedValueController = TextEditingController();
  
  File? _selectedImage;
  Uint8List? _selectedImageBytes; // For web
  String _category = 'Other';
  String _condition = 'Good';
  List<String> _keywords = [];
  bool _isAnalyzing = false;
  String _loadingMessage = "Teaching AI to appreciate your item's beauty...";
  Timer? _loadingMessageTimer;
  String? _imageError;
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  int _currentStep = 0;
  final List<GlobalKey<FormState>> _stepKeys = [GlobalKey<FormState>(), GlobalKey<FormState>()];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _estimatedValueController.dispose();
    _loadingMessageTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() { _imageError = null; });
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        if (bytes.length > maxFileSize) {
          setState(() {
            _imageError = 'Image is too large. Max file size is 5MB.';
            _selectedImageBytes = null;
            _selectedImage = null;
          });
          return;
        }
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImage = null;
        });
      } else {
        final file = File(image.path);
        if (await file.length() > maxFileSize) {
          setState(() {
            _imageError = 'Image is too large. Max file size is 5MB.';
            _selectedImage = null;
            _selectedImageBytes = null;
          });
          return;
        }
        setState(() {
          _selectedImage = file;
          _selectedImageBytes = null;
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    setState(() { _imageError = null; });
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final file = File(image.path);
      if (await file.length() > maxFileSize) {
        setState(() {
          _imageError = 'Image is too large. Max file size is 5MB.';
          _selectedImage = null;
          _selectedImageBytes = null;
        });
        return;
      }
      setState(() {
        _selectedImage = file;
        _selectedImageBytes = null;
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (kIsWeb && _selectedImageBytes == null) return;
    if (!kIsWeb && _selectedImage == null) return;

    final visionService = ref.read(visionServiceProvider);
    debugPrint('Starting image analysis...');
    setState(() {
      _isAnalyzing = true;
      _loadingMessage = visionService.getNextLoadingMessage();
    });
    debugPrint('Initial loading message: $_loadingMessage');
    _loadingMessageTimer?.cancel();
    _loadingMessageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isAnalyzing && mounted) {
        setState(() {
          _loadingMessage = visionService.getNextLoadingMessage();
        });
        debugPrint('Updated loading message: $_loadingMessage');
      } else {
        timer.cancel();
      }
    });
    try {
      Map<String, dynamic> result;
      if (kIsWeb && _selectedImageBytes != null) {
        result = await visionService.analyzeImageBytes(_selectedImageBytes!);
      } else if (!kIsWeb && _selectedImage != null) {
        result = await visionService.analyzeImage(_selectedImage!);
      } else {
        throw Exception('No image selected');
      }
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        setState(() {
          _titleController.text = data['title'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _category = data['category'] ?? 'Other';
          _condition = data['condition'] ?? 'Good';
          _brandController.text = data['brand'] ?? '';
          _estimatedValueController.text = data['estimatedValue'] ?? '';
          if (data['keywords'] != null) {
            _keywords = List<String>.from(data['keywords']);
          }
        });
        _nextStep();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        debugPrint('Analysis complete, isAnalyzing: $_isAnalyzing');
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || (_selectedImage == null && _selectedImageBytes == null)) return;
    setState(() => _isAnalyzing = true);
    try {
      String url;
      if (kIsWeb && _selectedImageBytes != null) {
        url = await ApiService().uploadImageBytes(_selectedImageBytes!);
      } else if (_selectedImage != null) {
        url = await ApiService().uploadImage(_selectedImage!);
      } else {
        throw Exception('No image selected');
      }
      await ApiService().createItem({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
        'condition': _condition,
        'images': [url],
        'brand': _brandController.text.trim(),
        'estimatedValue': _estimatedValueController.text.trim(),
        'keywords': _keywords,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item published!')),
      );
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _nextStep() {
    if (_currentStep < _stepKeys.length - 1) {
      setState(() => _currentStep++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publish Item')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step 1: Image Selection
                  if (_currentStep == 0)
                    Container(
                      key: _stepKeys[0],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (kIsWeb)
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Select Image'),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.photo_library),
                                    label: const Text('Select Image'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _takePhoto,
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Take Photo'),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 4),
                          Text('Max file size: 5MB', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          if (_imageError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(_imageError!, style: TextStyle(color: Colors.red, fontSize: 13)),
                            ),
                          const SizedBox(height: 12),
                          if (kIsWeb && _selectedImageBytes != null)
                            Image.memory(_selectedImageBytes!, height: 200, fit: BoxFit.cover)
                          else if (!kIsWeb && _selectedImage != null)
                            Image.file(_selectedImage!, height: 200, fit: BoxFit.cover),
                          if (_selectedImage != null || _selectedImageBytes != null) ...[
                            const SizedBox(height: 24),
                            // AI Analysis Button
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF00BCD4), // Teal
                                    const Color(0xFF2196F3), // Blue
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00BCD4).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isAnalyzing ? null : _analyzeImage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      child: _isAnalyzing
                                          ? const SizedBox(
                                              width: 32,
                                              height: 32,
                                              child: CircularProgressIndicator(
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                strokeWidth: 3,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.auto_awesome,
                                              size: 32,
                                            ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _isAnalyzing ? 'Analyzing...' : 'Analyze with AI',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (_isAnalyzing)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          _loadingMessage,
                                          style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Manual Input Button
                            OutlinedButton(
                              onPressed: _nextStep,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Enter Details Manually'),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Step 2: Item Details
                  if (_currentStep == 1)
                    Container(
                      key: _stepKeys[1],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(labelText: 'Title'),
                            validator: (v) => v == null || v.isEmpty ? 'Enter a title' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(labelText: 'Description'),
                            maxLines: 3,
                            validator: (v) => v == null || v.isEmpty ? 'Enter a description' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _brandController,
                            decoration: const InputDecoration(labelText: 'Brand'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _estimatedValueController,
                            decoration: const InputDecoration(labelText: 'Estimated Value'),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _category,
                            items: const [
                              DropdownMenuItem<String>(value: 'Electronics', child: Text('Electronics')),
                              DropdownMenuItem<String>(value: 'Furniture', child: Text('Furniture')),
                              DropdownMenuItem<String>(value: 'Clothing', child: Text('Clothing')),
                              DropdownMenuItem<String>(value: 'Books', child: Text('Books')),
                              DropdownMenuItem<String>(value: 'Sports', child: Text('Sports')),
                              DropdownMenuItem<String>(value: 'Other', child: Text('Other')),
                            ],
                            onChanged: (v) => setState(() => _category = v ?? 'Other'),
                            decoration: const InputDecoration(labelText: 'Category'),
                            validator: (v) => v == null ? 'Select a category' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _condition,
                            items: const [
                              DropdownMenuItem<String>(value: 'New', child: Text('New')),
                              DropdownMenuItem<String>(value: 'Like New', child: Text('Like New')),
                              DropdownMenuItem<String>(value: 'Good', child: Text('Good')),
                              DropdownMenuItem<String>(value: 'Fair', child: Text('Fair')),
                              DropdownMenuItem<String>(value: 'Poor', child: Text('Poor')),
                            ],
                            onChanged: (v) => setState(() => _condition = v ?? 'Good'),
                            decoration: const InputDecoration(labelText: 'Condition'),
                            validator: (v) => v == null ? 'Select a condition' : null,
                          ),
                          const SizedBox(height: 16),
                          // Submit Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00BCD4), // Teal
                                  const Color(0xFF2196F3), // Blue
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00BCD4).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isAnalyzing ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Column(
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: _isAnalyzing
                                        ? const SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              strokeWidth: 3,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.check_circle_outline,
                                            size: 32,
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isAnalyzing ? 'Publishing...' : 'Publish Item',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 