import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/vision_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../widgets/web_scaffold.dart';

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
  bool _analysisCompleted = false;
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
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (image != null) {
      final String fileName = image.name.toLowerCase();
      if (!fileName.endsWith('.jpg') && !fileName.endsWith('.jpeg') && 
          !fileName.endsWith('.png') && !fileName.endsWith('.webp')) {
        setState(() {
          _imageError = 'Unsupported image format. Please use JPG, PNG or WebP format.';
          _selectedImageBytes = null;
          _selectedImage = null;
        });
        return;
      }
      
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
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 1920,
      maxHeight: 1080,
    );
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
          _analysisCompleted = true;
        });
        _nextStep();
      } else {
        final errorMessage = result['error'] ?? 'Failed to analyze image';
        setState(() {
          if (errorMessage.contains('unsupported image')) {
            _imageError = 'The image format is not supported. Please try a different image in JPG, PNG or WebP format.';
          } else {
            _imageError = 'Analysis failed: $errorMessage';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e.toString().contains('unsupported image')) {
            _imageError = 'The image format is not supported. Please try a different image in JPG, PNG or WebP format.';
          } else {
            _imageError = 'Error analyzing image: $e';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_imageError ?? 'Error analyzing image')),
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

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WebScaffold(
        header: AppBar(
          title: const Text('Publish Item'),
          backgroundColor: Theme.of(context).colorScheme.background,
          elevation: 0,
          centerTitle: true,
        ),
        content: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            
            if (_currentStep == 0) {
              return _buildImageSelectionStep(availableHeight);
            } else {
              return _buildItemDetailsStep(availableHeight);
            }
          },
        ),
      ),
    );
  }

  Widget _buildImageSelectionStep(double availableHeight) {
    return Center(
      child: SingleChildScrollView(
        child: Form(
          key: _currentStep == 0 ? _formKey : GlobalKey<FormState>(),
          child: Container(
            key: _stepKeys[0],
            padding: const EdgeInsets.symmetric(vertical: 16),
            constraints: BoxConstraints(
              minHeight: min(360, availableHeight * 0.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (kIsWeb)
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Select Image'),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Select Image'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _takePhoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take a Photo'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Max file size: 5MB', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        if (_imageError != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _imageError!,
                                    style: const TextStyle(color: Colors.red, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (kIsWeb && _selectedImageBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              _selectedImageBytes!, 
                              height: 200, 
                              width: 200,
                              fit: BoxFit.cover
                            ),
                          )
                        else if (!kIsWeb && _selectedImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              _selectedImage!, 
                              height: 200, 
                              width: 200,
                              fit: BoxFit.cover
                            ),
                          ),
                        if (_selectedImage != null || _selectedImageBytes != null) ...[
                          const SizedBox(height: 20),
                          if (!_analysisCompleted)
                            Container(
                              width: double.infinity,
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
                                  minimumSize: const Size.fromHeight(60),
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
                          if (!_isAnalyzing && !_analysisCompleted)
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD54F), // Amber 300
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFB300).withOpacity(0.3), // Amber 700
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _nextStep,
                                icon: const Icon(Icons.edit),
                                label: const Text('Enter Details Manually'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          if (_analysisCompleted && !_isAnalyzing)
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF00BCD4), // Teal
                                    const Color(0xFFFF9800), // Orange
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
                              child: ElevatedButton.icon(
                                onPressed: _nextStep,
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('Continue to Details'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemDetailsStep(double availableHeight) {
    return Form(
      key: _currentStep == 1 ? _formKey : GlobalKey<FormState>(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back button row
              ElevatedButton.icon(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              
              // Image preview with better size
              const SizedBox(height: 20),
              Center(
                child: kIsWeb && _selectedImageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _selectedImageBytes!,
                        height: 200,
                        width: 200,
                        fit: BoxFit.cover,
                      ),
                    )
                  : _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          height: 200,
                          width: 200,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const SizedBox(),
              ),
              
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                validator: (v) => v == null || v.isEmpty ? 'Enter a description' : null,
              ),
              const SizedBox(height: 16),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _estimatedValueController,
                      decoration: const InputDecoration(
                        labelText: 'Estimated Value',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
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
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (v) => v == null ? 'Select a category' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _condition,
                      items: const [
                        DropdownMenuItem<String>(value: 'New', child: Text('New')),
                        DropdownMenuItem<String>(value: 'Like New', child: Text('Like New')),
                        DropdownMenuItem<String>(value: 'Good', child: Text('Good')),
                        DropdownMenuItem<String>(value: 'Fair', child: Text('Fair')),
                        DropdownMenuItem<String>(value: 'Poor', child: Text('Poor')),
                      ],
                      onChanged: (v) => setState(() => _condition = v ?? 'Good'),
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (v) => v == null ? 'Select a condition' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
} 