// lib/screens/camouflage/fake_apps/weather_app.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/themes/app_themes.dart';
import '../../../core/themes/app_theme_extension.dart';
import '../../../core/managers/settings_manager.dart';
import '../../auth/login_screen.dart';

class WeatherApp extends StatefulWidget {
  const WeatherApp({super.key});

  @override
  State<WeatherApp> createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  int _secretTapCount = 0;
  String _selectedCity = 'الرياض';
  bool _isRefreshing = false;
  List<String> _secretTapSequence = [];
  
  final List<String> _cities = [
    'الرياض', 'جدة', 'مكة المكرمة', 'المدينة المنورة', 
    'الدمام', 'تبوك', 'أبها', 'بريدة'
  ];

  final Map<String, WeatherData> _weatherData = {
    'الرياض': WeatherData(
      temperature: 28,
      condition: 'مشمس',
      humidity: 45,
      windSpeed: 12,
      icon: Icons.wb_sunny,
      color: Colors.orange,
      forecast: [
        DayForecast('الغد', 30, 18, Icons.wb_sunny),
        DayForecast('الأحد', 32, 20, Icons.wb_sunny),
        DayForecast('الاثنين', 29, 17, Icons.cloud),
        DayForecast('الثلاثاء', 26, 15, Icons.cloud),
      ]
    ),
    'جدة': WeatherData(
      temperature: 35,
      condition: 'حار',
      humidity: 75,
      windSpeed: 8,
      icon: Icons.wb_sunny,
      color: Colors.red,
      forecast: [
        DayForecast('الغد', 37, 26, Icons.wb_sunny),
        DayForecast('الأحد', 36, 25, Icons.wb_sunny),
        DayForecast('الاثنين', 34, 24, Icons.cloud),
        DayForecast('الثلاثاء', 33, 23, Icons.cloud),
      ]
    ),
    'مكة المكرمة': WeatherData(
      temperature: 38,
      condition: 'حار جداً',
      humidity: 35,
      windSpeed: 6,
      icon: Icons.wb_sunny,
      color: Colors.deepOrange,
      forecast: [
        DayForecast('الغد', 40, 28, Icons.wb_sunny),
        DayForecast('الأحد', 39, 27, Icons.wb_sunny),
        DayForecast('الاثنين', 37, 26, Icons.wb_sunny),
        DayForecast('الثلاثاء', 36, 25, Icons.cloud),
      ]
    ),
  };

  @override
  Widget build(BuildContext context) {
    final weather = _weatherData[_selectedCity] ?? _weatherData['الرياض']!;
    
    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        backgroundColor: Colors.lightBlue[400],
        elevation: 0,
        title: const Text(
          'الطقس',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _refreshWeather,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            onPressed: _showMenu,
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshWeather,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildCurrentWeather(weather),
              _buildHourlyForecast(weather),
              _buildWeeklyForecast(weather),
              _buildWeatherDetails(weather),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentWeather(WeatherData weather) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.lightBlue[400]!,
            Colors.lightBlue[300]!,
          ],
        ),
      ),
      child: Column(
        children: [
          DropdownButton<String>(
            value: _selectedCity,
            dropdownColor: Colors.lightBlue[300],
            style: const TextStyle(color: Colors.white, fontSize: 18),
            underline: Container(),
            items: _cities.map((city) {
              return DropdownMenuItem(
                value: city,
                child: Text(city),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedCity = value;
                });
              }
            },
          ),
          const SizedBox(height: 20),
          Icon(
            weather.icon,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            '${weather.temperature}°',
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w300,
              color: Colors.white,
            ),
          ),
          Text(
            weather.condition,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherStat('الرطوبة', '${weather.humidity}%', Icons.water_drop),
              _buildWeatherStat('الرياح', '${weather.windSpeed} كم/س', Icons.air),
              _buildWeatherStat('الوقت', _getCurrentTime(), Icons.access_time),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherStat(String label, String value, IconData icon) {
    return GestureDetector(
      onTap: () {
        _secretTapSequence.add(label);
        if (_secretTapSequence.length > 3) {
          _secretTapSequence.removeAt(0);
        }
        if (_secretTapSequence.join(',') == 'الرطوبة,الرياح,الوقت') {
          _accessRealApp();
        }
      },
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyForecast(WeatherData weather) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 24,
        itemBuilder: (context, index) {
          final hour = (DateTime.now().hour + index) % 24;
          final temp = weather.temperature + (index % 2 == 0 ? -2 : 1);
          
          return Container(
            width: 60,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  '$hour:00',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Icon(
                  weather.icon,
                  size: 24,
                  color: weather.color,
                ),
                Text(
                  '$temp°',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyForecast(WeatherData weather) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'توقعات الأسبوع',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          ...weather.forecast.map((day) => _buildDayForecast(day)),
        ],
      ),
    );
  }

  Widget _buildDayForecast(DayForecast day) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              day.day,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Icon(day.icon, size: 24, color: Colors.lightBlue),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${day.low}°',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Text(
                  '${day.high}°',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetails(WeatherData weather) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'تفاصيل الطقس',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          _buildDetailRow('الرؤية', '10 كم', Icons.visibility),
          _buildDetailRow('الضغط', '1013 هكتوباسكال', Icons.speed),
          _buildDetailRow('مؤشر الأشعة', 'عالي', Icons.wb_sunny),
          _buildDetailRow('الشروق', '06:15', Icons.wb_sunny_outlined),
          _buildDetailRow('الغروب', '18:45', Icons.nights_stay),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.lightBlue),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshWeather() async {
    setState(() {
      _isRefreshing = true;
    });
    
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث بيانات الطقس'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showMenu() {
    _secretTapCount++;
    if (_secretTapCount >= 6) {
      _accessRealApp();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.lightBlue),
              title: const Text('إدارة المواقع'),
              onTap: () {
                Navigator.pop(context);
                _showLocations();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.notifications, color: Colors.lightBlue),
              title: const Text('التنبيهات'),
              onTap: () {
                Navigator.pop(context);
                _showNotifications();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.lightBlue),
              title: const Text('الإعدادات'),
              onTap: () {
                Navigator.pop(context);
                _showSettings();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.lightBlue),
              title: const Text('حول التطبيق'),
              onTap: () {
                Navigator.pop(context);
                _showAbout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLocations() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('المواقع المحفوظة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _cities.map((city) => ListTile(
            title: Text(city),
            trailing: city == _selectedCity ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () {
              setState(() {
                _selectedCity = city;
              });
              Navigator.pop(context);
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('التنبيهات الجوية'),
        content: const Text('لا توجد تنبيهات جوية حالياً'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات الطقس'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.thermostat),
              title: Text('وحدة الحرارة'),
              trailing: Text('مئوية'),
            ),
            ListTile(
              leading: Icon(Icons.air),
              title: Text('وحدة الرياح'),
              trailing: Text('كم/س'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حول تطبيق الطقس'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإصدار: 3.2.1'),
            SizedBox(height: 8),
            Text('تطبيق للطقس مع توقعات دقيقة ومحدثة'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _accessRealApp() {
    HapticFeedback.heavyImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}

class WeatherData {
  final int temperature;
  final String condition;
  final int humidity;
  final int windSpeed;
  final IconData icon;
  final Color color;
  final List<DayForecast> forecast;

  WeatherData({
    required this.temperature,
    required this.condition,
    required this.humidity,
    required this.windSpeed,
    required this.icon,
    required this.color,
    required this.forecast,
  });
}

class DayForecast {
  final String day;
  final int high;
  final int low;
  final IconData icon;

  DayForecast(this.day, this.high, this.low, this.icon);
}