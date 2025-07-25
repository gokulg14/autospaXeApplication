import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import 'Details.dart';
import 'SearchPage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

final double _fixedZoomLevel = 16.5;
final double minzoom = 20;
final LatLng _currentLocation = LatLng(9.31741, 76.61764);

class HomeScreen extends StatefulWidget {
  final String? userMail;

  const HomeScreen({super.key, this.userMail});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

double _calculateDistance(LatLng start, LatLng end) {
  const double radius = 6371; // Radius of the Earth in km
  double lat1 = start.latitude * pi / 180;
  double lon1 = start.longitude * pi / 180;
  double lat2 = end.latitude * pi / 180;
  double lon2 = end.longitude * pi / 180;

  double dlat = lat2 - lat1;
  double dlon = lon2 - lon1;

  // Haversine formula
  double a = sin(dlat / 2) * sin(dlat / 2) +
      cos(lat1) * cos(lat2) * sin(dlon / 2) * sin(dlon / 2);
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  // Distance in kilometers
  double distance = radius * c;

  return distance; // Return distance in kilometers
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService apiService = ApiService();

  late Future<List<Map<String, dynamic>>> _futureParkingSpots;

  // Keep track of the current selected tab in the BottomNavigationBar
  int _currentIndex = 0;

  // List of screens or widgets you want to show for each tab
  final List<Widget> _screens = [
    // The screen containing the map
  ];

  // Function to change the tab
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  int _selectedIndex = 0;
  LatLng? _currentLocation;
  LatLng? _selectedLocation; // For storing selected destination location
  final Location _location = Location();
  late MapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  List<Polyline> _polylines = []; // For storing polylines between locations
  bool _locationPermissionGranted = false;
  late final String parkingId;

  late List<Map<String, dynamic>> _parkingLocations = []; /*= [
    {
      "name": "Pranav Parking",
      "location": LatLng(9.3906, 76.5583),
      "isVisible": true,
    },
    {
      "name": "Gedi Parking",
      "location": LatLng(9.4000, 76.5650),
      "isVisible": true,
    },
    {
      "name": "Airport Parking Zone",
      "location": LatLng(9.6001, 76.3805),
      "isVisible": true,
    },
    {
      "name": "Auto Spaxe Chengannur",
      "location": LatLng(9.3155, 76.6158),
      "isVisible": true,
    },
  ];*/

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _checkPermissions();
    //_futureParkingSpots = apiService.getNearbyParkingSpots();
    _fetchParkingSpots();
    Provider.of<UserProvider>(context, listen: false).setUserProvider(
      userEmail: widget.userMail.toString()
    );

  }

  void _fetchParkingSpots() {
    _futureParkingSpots = apiService.getNearbyParkingSpots(); // Store the Future

    _futureParkingSpots.then((spots) {
      setState(() {
        _parkingLocations = spots.map((spot) {
          List<String> latLngStr = spot['location'].split(',');
          double latitude = double.parse(latLngStr[0].trim());
          double longitude = double.parse(latLngStr[1].trim());

          return {
            'name': spot['name'],
            'location': LatLng(latitude, longitude),
            'isVisible': true,
          };
        }).toList();
      });

      print("Parking locations updated: $_parkingLocations"); // Print after assignment
    }).catchError((error) {
      print("Error loading parking spots: $error");
    });
  }


  void _checkPermissions() async {
    PermissionStatus permissionStatus = await _location.hasPermission();
    if (permissionStatus == PermissionStatus.granted) {
      _locationPermissionGranted = true;
      _startLocationUpdates();
    } else {
      permissionStatus = await _location.requestPermission();
      if (permissionStatus == PermissionStatus.granted) {
        _locationPermissionGranted = true;
        _startLocationUpdates();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission denied.")),
        );
      }
    }
  }

  void _startLocationUpdates() {
    _location.onLocationChanged.listen((LocationData locationData) {
      setState(() {
        _currentLocation =
            LatLng(locationData.latitude!, locationData.longitude!);
        _mapController.move(_currentLocation!, _fixedZoomLevel);
      });
    });
  }

  void _onButtonTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _navigateToSearchPage() async {
    if (_currentLocation != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TomTomRoutingPage(
            currentLocation: _currentLocation!,
            onRouteUpdated: _updateRoute,
            parkingSpot: {},
            parkingLocations: _parkingLocations,
          ),
        ),
      );

      if (result != null && result is LatLng) {
        _selectedLocation = result;
        _searchController.text =
            "Destination: ${result.latitude}, ${result.longitude}";
        _addRoute(_currentLocation!, _selectedLocation!);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to fetch your current location.")),
      );
    }
  }

  void _addRoute(LatLng start, LatLng destination) {
    setState(() {
      _polylines = [
        Polyline(
          points: [start, destination],
          strokeWidth: 4.0,
          color: Colors.blue,
        ),
      ];
    });
  }

  void _updateRoute(List<LatLng> routeCoordinates) {
    setState(() {
      _polylines = [
        Polyline(
          points: routeCoordinates,
          strokeWidth: 6,
          color: const Color.fromARGB(255, 243, 51, 33),
        ),
      ];
    });
  }

  void _animateCarAlongRoute() async {
    if (_currentLocation == null || _selectedLocation == null) return;

    // Get the route points (polyline coordinates)
    List<LatLng> route = _polylines[0].points;
    if (route.isEmpty) return;

    // Iterate over the points and animate the car's position along the route
    for (int i = 1; i < route.length; i++) {
      LatLng start = route[i - 1]; // Start point
      LatLng end = route[i]; // End point
      double distance =
          _calculateDistance(start, end); // Calculate distance between points
      double stepSize = 0.05; // Adjust for the speed of the car animation
      double steps = distance / stepSize; // Number of steps for the animation

      // Loop through the steps to simulate car movement
      for (double j = 0; j <= steps; j++) {
        double progress =
            j / steps; // Progress of the car moving from start to end
        LatLng newLocation = LatLng(
          start.latitude + (end.latitude - start.latitude) * progress,
          start.longitude + (end.longitude - start.longitude) * progress,
        );

        // Update the car's location
        setState(() {
          _currentLocation = newLocation;
        });

        // Wait before updating the position to simulate movement
      }
    }
  }

  Future<Map<String, dynamic>?> fetchParkingSpotById(int parkingId) async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:8080/api/parking-spots/$parkingId'));

      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'id': data['id'],
          'name': data['name'],
          'description': data['description'],
          'imageUrl': data['imageUrl'],
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'ratePerHour': data['ratePerHour'],
        };
      } else {
        throw Exception("Failed to load parking spot: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching parking spot: $e");
      return null;
    }
  }

  void _updateMarkerVisibility(double zoomLevel) {
    setState(() {
      if (zoomLevel > 13.5) {
        _parkingLocations = _parkingLocations
            .map((parking) => {...parking, "isVisible": true})
            .toList();
      } else {
        _parkingLocations = _parkingLocations
            .map((parking) => {...parking, "isVisible": false})
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Add sample content to debug
            buildCardWithImageTextAndButton(),
            // Buttons at the top
            _buildMapView(),
            // Map View section
            _buildSearchBar(),
            // Search Bar
            _buildNearbySpotsContainer(),
            _buildParkingSpotsList(context)
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return Container(
      height: 500, // Set a fixed height for the map view
      child: Center(
        child: _buildTomTomMap(), // Always show the TomTom map
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _navigateToSearchPage,
                  // Navigates to the search page on tap
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      // Black background for the search bar
                      borderRadius:
                          BorderRadius.circular(16), // Rounded corners
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white),
                        // White search icon
                        const SizedBox(width: 10),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Search for parking...'
                              : _searchController.text,
                          style: TextStyle(
                            color: _searchController.text.isEmpty
                                ? Colors.white.withOpacity(
                                    0.5) // Light grey color for hint
                                : Colors.white,
                            // White text when text is entered
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget buildCardWithImageTextAndButton() {
    return Container(
      margin: const EdgeInsets.all(16.0), // Margin around the container
      decoration: BoxDecoration(
        color: const Color.fromARGB(193, 6, 73, 218),
        borderRadius: BorderRadius.circular(16), // Rounded corners
        border: Border.all(color: const Color.fromARGB(38, 0, 0, 0), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(50, 0, 0, 0).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(2, 2), // Shadow position
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Image container
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          // Random text or content
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'The button has some padding to make it look like a card button. You can customize the button style and action as per!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
          // Button container
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerLeft, // Aligns the button to the left
              child: ElevatedButton(
                onPressed: () {
                  // Handle button press here
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.blue, // Button color
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0), // Adjust padding for smaller button
                ),
                child: Text(
                  'Click Here',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight
                          .bold), // Smaller text size for a smaller button
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTomTomMap() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color.fromARGB(38, 0, 0, 0), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(50, 0, 0, 0).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation ?? LatLng(0.0, 0.0),
            initialZoom: _fixedZoomLevel,
            // Set the initial zoom level to your fixed level
            minZoom: 13,
            // Set the minimum zoom level
            maxZoom: 20,
            // Optional: Set the maximum zoom level

            onPositionChanged: (_, isGesturing) {
              // Adjust the visibility based on zoom level
              if (_mapController.zoom <= 13) {
                _updateMarkerVisibility(
                    13); // Limit marker visibility if zoomed out
              } else {
                _updateMarkerVisibility(_mapController.zoom);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?key=8CKwch3uCDAuLbcrffLiAx8IdhU9bGKS',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: _parkingLocations.map((parking) {
                return Marker(
                  point: parking["location"],
                  width: 150,
                  height: parking["isVisible"] == true ? 80 : 0,
                  child: parking["isVisible"] == true
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on,
                                color: Colors.red, size: 40),
                            const SizedBox(height: 5),
                            Text(
                              parking["name"],
                              style: const TextStyle(
                                color: Color.fromARGB(255, 230, 12, 12),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                );
              }).toList(),
            ),
            PolylineLayer(
              polylines: _polylines,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(int index, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        onTap: () => _onButtonTap(index),
        child: Card(
          color: _selectedIndex == index
              ? const Color.fromARGB(255, 69, 204, 255)
              : Colors.grey[300],
          elevation: 3,
          child: Container(
            width: 100,
            height: 100,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              children: [
                Icon(icon,
                    color:
                        _selectedIndex == index ? Colors.white : Colors.black),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    color:
                        _selectedIndex == index ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNearbySpotsContainer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nearby Parking Spots',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'View nearby parking spots and choose the best option.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToRoutePage(
      BuildContext context, Map<String,dynamic> parkingSpot) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TomTomRoutingPage(
          parkingLocations: _parkingLocations,
          currentLocation: _currentLocation!,
          parkingSpot: parkingSpot,
          onRouteUpdated: (route) {
            // Handle route update here if needed
          },
        ),
      ),
    );
  }

  /*void _navigateToD(
      BuildContext context, String parkingId, String parkingName) {
    print("Navigating to Parking ID: $parkingId, Name: $parkingName");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TomTomRoutD(
          parkingId: parkingId, // Pass parkingId to the next screen
        ),
      ),
    );
  }*/



  Widget _buildParkingSpotsList(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futureParkingSpots, // Fetch data
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No nearby parking spots found"));
        }

        final parkingSpots = snapshot.data!;
        final screenWidth =
            MediaQuery.of(context).size.width; // Get screen width
        final screenHeight =
            MediaQuery.of(context).size.height; // Get screen height

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: parkingSpots.length,
            itemBuilder: (context, index) {
              final parkingSpot = parkingSpots[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 10.0),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 33, 33, 33),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color.fromARGB(105, 0, 0, 0).withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                height: screenWidth < 600 ? 250 : 200,
                // Increase height for smaller screens
                width: screenWidth * 0.9,
                // Make it 90% of screen width

                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        convertToImage(parkingSpot['imageUrl']),
                        width: screenWidth < 600 ? 100 : 150,
                        // Adjust image size for small screens
                        height: screenWidth < 600 ? 190 : 160,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.image_not_supported, size: 120),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            parkingSpot['name']!,
                            style: TextStyle(
                              fontSize: screenWidth < 600 ? 14 : 16,
                              // Adjust font size
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            parkingSpot['description']!,
                            style: TextStyle(
                              fontSize: screenWidth < 600 ? 12 : 14,
                              // Adjust font size
                              color: Color.fromARGB(255, 246, 245, 245),
                            ),
                            maxLines: screenWidth < 600 ? 8 : 10,
                            // Limit lines for smaller screens
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  _navigateToRoutePage(
                                    context,
                                    parkingSpot,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth < 600 ? 20 : 30,
                                    // Adjust padding
                                    vertical: 10,
                                  ),
                                ),
                                child: const Text('Direction'),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () {
                                  /*_navigateToD(
                                    context,
                                    parkingSpot['id'].toString(),
                                    // Ensure parking ID is a String
                                    parkingSpot['name']!,
                                  );*/
                                },
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth < 600 ? 20 : 30,
                                    // Adjust padding
                                    vertical: 10,
                                  ),
                                ),
                                child: const Text('Details'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Uint8List convertToImage(imageBase64) {
    return Base64Decoder().convert(imageBase64);
  }
}

extension on MapController {
  get zoom => 20;
}
