import 'package:autospaxe/screens/maps/booking_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ruler_picker/flutter_ruler_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/ParkingProvider.dart';
import 'circular_time_picker.dart';

class DateTimePickerPage extends StatefulWidget {
  final String slotId;
  final String slotType;
  final String slotNumber;
  const DateTimePickerPage({super.key, required this.slotId, required this.slotType, required this.slotNumber});

  @override
  _DateTimePickerPageState createState() => _DateTimePickerPageState();
}

class _DateTimePickerPageState extends State<DateTimePickerPage> with SingleTickerProviderStateMixin {
  // Controllers
  late RulerPickerController _rulerPickerController;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // State variables
  num currentValue = 0;
  DateTime? selectedDate;
  int selectedHours = 1;
  bool isFourWheeler = true;
  bool _isInteracting = false;
  bool _showButton = false;


  // Time ranges for ruler picker
  List<RulerRange> timeRanges = const [
    RulerRange(begin: -12, end: 12, scale: 0.05),
  ];

  @override
  void initState() {
    super.initState();
    _rulerPickerController = RulerPickerController(value: currentValue);

    isFourWheeler = widget.slotType.toLowerCase() == 'car';

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Create animations
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.elasticOut)
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn)
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Utility methods
  String formatTime(num value) {
    int totalMinutes = ((value + 12) * 60).toInt();
    int hour = (totalMinutes ~/ 60) % 24;
    int minutes = totalMinutes % 60;
    String period = hour >= 12 ? "PM" : "AM";
    int displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return "$displayHour:${minutes.toString().padLeft(2, '0')} $period";
  }

  String calculateEndTime() {
    int totalMinutes = ((currentValue + 12) * 60).toInt();
    int hour = (totalMinutes ~/ 60) % 24;
    int minutes = totalMinutes % 60;
    DateTime startTime = DateTime(2025, 1, 1, hour, minutes);
    DateTime endTime = startTime.add(Duration(hours: selectedHours));
    return DateFormat('hh:mm a').format(endTime);
  }

  int calculateFare(){
    String ratePerHour = Provider.of<ParkingProvider>(context, listen: false).ratePerHour;
    int rate = double.parse(ratePerHour).toInt();
    return selectedHours * rate + 50;
  }

  bool _areAllFieldsEntered() => selectedDate != null;

  // UI interaction methods
  Future<void> _selectDate(BuildContext context) async {
    setState(() {
      _isInteracting = true;
      _hideButton();
    });

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }

    setState(() {
      _isInteracting = false;
      _checkAndShowButton();
    });
  }

  void _updateSelectedHours(int newHours) {
    setState(() {
      _isInteracting = true;
      _hideButton();
      selectedHours = newHours;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isInteracting = false;
          _checkAndShowButton();
        });
      }
    });
  }

  void _handleRulerValueChanged(num value) {
    setState(() {
      _isInteracting = true;
      _hideButton();
      currentValue = value;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isInteracting = false;
          _checkAndShowButton();
        });
      }
    });
  }

  void _hideButton() {
    if (_showButton) {
      setState(() {
        _showButton = false;
      });
      _animationController.reverse();
    }
  }

  void _checkAndShowButton() {
    if (!_isInteracting && _areAllFieldsEntered() && !_showButton) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_isInteracting && _areAllFieldsEntered()) {
          setState(() {
            _showButton = true;
          });
          _animationController.forward();
        }
      });
    } else if (!_areAllFieldsEntered() && _showButton) {
      _hideButton();
    }
  }

  void _handleSubmit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingPage(slotId: widget.slotId, slotType: widget.slotType, slotNumber: widget.slotNumber, fare: calculateFare(), endDate: selectedDate, endTime: calculateEndTime(), startTime: formatTime(currentValue)),
      ),
    );
    print(formatTime(currentValue));
    print(calculateEndTime());
    print(selectedDate);
    print(calculateFare());
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: AppBar(
          backgroundColor: Colors.white.withOpacity(0.5),
          elevation: 0,
          flexibleSpace: Padding(
            padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.black, Colors.deepPurple],
                ).createShader(bounds),
                child: const Text(
                  "Please Select Further Information",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main scrollable content
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(height: 20),

                      // Vehicle Type Selector
                      _buildVehicleTypeSelector(),

                      // NOTE: Vehicle info summary is permanently hidden
                      // but the related logic remains intact

                      const SizedBox(height: 20),

                      // Date Picker Button
                      _buildDatePickerButton(),

                      const SizedBox(height: 30),

                      // Time Display
                      Text(
                        formatTime(currentValue),
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 10),

                      // Time Ruler Picker
                      RulerPicker(
                        controller: _rulerPickerController,
                        onBuildRulerScaleText: (index, value) => formatTime(value),
                        ranges: timeRanges,
                        width: MediaQuery.of(context).size.width * 0.9,
                        height: 100,
                        onValueChanged: _handleRulerValueChanged,
                      ),

                      const SizedBox(height: 10),

                      // "From - To" & Fare Display
                      _buildTimeAndFareDisplay(),

                      const SizedBox(height: 10),

                      // Circular Duration Picker
                      SizedBox(
                        height: 250,
                        child: CircleMenu(
                          onHoursChanged: _updateSelectedHours,
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Floating Submit Button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // UI Component Methods
  Widget _buildVehicleTypeSelector() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.deepPurpleAccent, Colors.purple],
        ),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _vehicleOption("Two Wheeler", false),
          _vehicleOption("Four Wheeler", true),
        ],
      ),
    );
  }

  Widget _vehicleOption(String label, bool isFourWheelerOption) {
    bool isSelected = isFourWheeler == isFourWheelerOption;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: isSelected ? Colors.yellowAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.purple : Colors.white,
        ),
      ),
    );
  }

  Widget _buildDatePickerButton() {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selectedDate == null ? Colors.redAccent : Colors.purple,
            width: 2,
          ),
          boxShadow: selectedDate == null ? [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.3),
              blurRadius: 4,
              spreadRadius: 1,
            )
          ] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              color: selectedDate == null ? Colors.redAccent : Colors.purple,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              selectedDate != null
                  ? DateFormat('dd MMM yyyy').format(selectedDate!)
                  : "Select Date *",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: selectedDate == null ? Colors.redAccent : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeAndFareDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _timeBlock("From", formatTime(currentValue), Icons.access_time),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
            _timeBlock("To", calculateEndTime(), Icons.timer_off),
            _timeBlock("Fare", "₹${calculateFare()}", Icons.attach_money),
          ],
        ),
      ),
    );
  }

  Widget _timeBlock(String title, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.white70)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Center(
                child: Container(
                  height: 60,
                  width: 220,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 5,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepPurple,
                        Colors.deepPurple.shade700,
                        Colors.purple.shade800,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: _showButton ? _handleSubmit : null,
                      splashColor: Colors.white.withOpacity(0.2),
                      highlightColor: Colors.transparent,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'CONFIRM',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}