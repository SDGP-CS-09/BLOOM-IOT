import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:http_parser/http_parser.dart'; // For MediaType

class PlantRecognitionScreen extends StatefulWidget {
  const PlantRecognitionScreen({super.key});

  @override
  _PlantRecognitionScreenState createState() => _PlantRecognitionScreenState();
}

class _PlantRecognitionScreenState extends State<PlantRecognitionScreen> {
  File? _image;
  String _errorMessage = '';
  Map<String, dynamic>? _plantData;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  String? _selectedModel;

  static const Map<String, String> _specializedAPIs = {
    'Bell Pepper': 'https://bellpepper-production.up.railway.app/predict',
    'Corn': 'https://corn-production.up.railway.app/predict',
    'Eggplant': 'https://eggplant-production.up.railway.app/predict',
    'Potato': 'https://potato-production.up.railway.app/predict',
  };

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.photos,
    ].request();

    return statuses[Permission.camera]!.isGranted &&
        statuses[Permission.photos]!.isGranted;
  }

  Future<void> _captureImage() async {
    try {
      if (await _requestPermissions()) {
        final XFile? image =
            await _picker.pickImage(source: ImageSource.camera);
        if (image != null) {
          setState(() {
            _image = File(image.path);
            _errorMessage = '';
            _plantData = null;
          });
          await _analyzePlant();
        }
      } else {
        setState(() {
          _errorMessage = 'Camera and gallery permissions are required';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error capturing image: $e';
      });
    }
  }

  Future<void> _uploadImage() async {
    try {
      if (await _requestPermissions()) {
        final XFile? image =
            await _picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          setState(() {
            _image = File(image.path);
            _errorMessage = '';
            _plantData = null;
          });
          await _analyzePlant();
        }
      } else {
        setState(() {
          _errorMessage = 'Gallery permissions are required';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error uploading image: $e';
      });
    }
  }

  Future<void> _analyzePlant() async {
    if (_image == null) {
      setState(() {
        _errorMessage = 'No image selected';
      });
      return;
    }

    if (_selectedModel == null) {
      setState(() {
        _errorMessage = 'Please select a plant model first';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _analyzeWithSpecializedAPI(_specializedAPIs[_selectedModel]!);
    } catch (e) {
      setState(() {
        _plantData = null;
        _errorMessage = 'Failed to analyze plant: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _analyzeWithSpecializedAPI(String apiUrl) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Add the file with the correct field name and content type
      String fieldName =
          'file'; // Adjust this based on API documentation (e.g., 'image')
      String fileExtension = _image!.path.split('.').last.toLowerCase();
      String mimeType = fileExtension == 'png' ? 'image/png' : 'image/jpeg';

      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          _image!.path,
          contentType: MediaType('image', fileExtension),
        ),
      );

      // Add headers (adjust as needed based on API requirements)
      request.headers['Content-Type'] = 'multipart/form-data';
      // Uncomment and add API key if required
      // request.headers['Authorization'] = 'Bearer YOUR_API_KEY';

      // Add additional fields if required by the API
      // request.fields['model'] = _selectedModel!.toLowerCase();

      final response =
          await request.send().timeout(const Duration(seconds: 30));
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        setState(() {
          _plantData = {
            'name': jsonResponse['class'] ?? 'Unknown',
            'confidence': ((jsonResponse['confidence'] as num?) ?? 0.0 * 100)
                .toStringAsFixed(2),
            'source': _selectedModel
          };
          _errorMessage = '';
        });
      } else {
        // Log the response body for debugging
        print('Error response from $apiUrl: $responseData');
        throw Exception('Status ${response.statusCode}: $responseData');
      }
    } catch (e) {
      throw Exception('API request failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Stack(
          children: [
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.45),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.green),
                ),
              ),
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: DropdownButton<String>(
                value: _selectedModel,
                hint: const Text('Select Model'),
                items: _specializedAPIs.keys.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedModel = newValue;
                    _plantData = null;
                    _errorMessage = '';
                  });
                },
              ),
            ),
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _errorMessage.isNotEmpty
                      ? _errorMessage
                      : 'Capture or Upload a Plant Image',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                height: 300,
                width: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  color: Colors.grey[200],
                ),
                child: _image != null
                    ? Image.file(_image!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.error))
                    : const Center(child: Icon(Icons.camera_alt, size: 50)),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: _plantData != null || _errorMessage.isNotEmpty
                  ? _buildResultCard()
                  : _buildActionButtons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _plantData != null
            ? [
                Text(
                  'Name: ${_plantData?['name'] ?? 'Unknown'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Confidence: ${_plantData?['confidence'] ?? 'N/A'}%',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Text(
                  'Source: ${_plantData?['source'] ?? 'Unknown'}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ]
            : [
                Text(
                  'Analysis Error',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _captureImage,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Capture Image',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _isLoading ? null : _uploadImage,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.green, width: 2),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Upload Image',
            style: TextStyle(color: Colors.green, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
