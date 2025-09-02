import 'package:flutter/material.dart';

import 'colors.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SignUP(),
  ));
}

class SignUP extends StatelessWidget {
  const SignUP({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
            child: Column(children: [
          // Top Rounded Green Header
          Container(
            height: screenHeight / 3, // 1/3rd of screen height
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFA0AEC0),
                  Color.fromARGB(255, 77, 87, 92),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'logo',
                  child: Image.asset(
                    'images/logo.png',
                    height: 78,
                    width: 78,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Guardian Angel',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Watching over when you can\'t',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 30,
          ),

          const Text(
            'Become a Member Now!',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: CloudMistColors.textBoss),
          ),

          const SizedBox(height: 44),

          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: CloudMistColors.bossGray,
              elevation: 1,
              minimumSize: const Size(260, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: SizedBox(
              width: 250,
              child: Row(
                children: [
                  Image.asset(
                    'images/google-logo.png',
                    height: 25,
                    width: 25,
                  ),
                  const SizedBox(
                    width: 20,
                  ),
                  const Text(
                    'Signup With Google',
                    style: TextStyle(
                        fontSize: 18,
                        color: CloudMistColors
                            .fullWhite, // Optional: Add to CloudMistColors as primaryGreen
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 34),

          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: CloudMistColors.bossGray,
              elevation: 1,
              minimumSize: const Size(220, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const SizedBox(
              width: 250,
              child: Row(
                children: [
                  Icon(
                    FontAwesomeIcons.apple,
                    size: 30,
                    color: Colors.black,
                  ),
                  SizedBox(
                    width: 20,
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 1),
                    child: Text(
                      'Signup With Apple',
                      style: TextStyle(
                          fontSize: 18,
                          color: CloudMistColors
                              .fullWhite, // Optional: Add to CloudMistColors as primaryGreen
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 34,
          ),
          const Row(
            children: [
              Expanded(
                child: Divider(
                  color: CloudMistColors.textBoss,
                  thickness: 1,
                  indent: 9,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  'OR SIGNUP WITH',
                  style: TextStyle(
                    color: CloudMistColors.textBoss,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: CloudMistColors.textBoss,
                  thickness: 1,
                  endIndent: 9,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 34,
          ),
          const PhoneNumberInput(),
          const SizedBox(
            height: 34,
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: CloudMistColors.bossGray,
              elevation: 1,
              minimumSize: const Size(100, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const SizedBox(
              width: 90,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Signup',
                    style: TextStyle(
                        fontSize: 20,
                        color: CloudMistColors
                            .fullWhite, // Optional: Add to CloudMistColors as primaryGreen
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 34,
          ),

          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already a member?',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: CloudMistColors.textBoss),
              ),
              SizedBox(
                width: 6,
              ),
              Text('Login',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: CloudMistColors.textBoss)),
            ],
          )
        ])));
  }
}

class PhoneNumberInput extends StatefulWidget {
  const PhoneNumberInput({super.key});

  @override
  State<PhoneNumberInput> createState() => _PhoneNumberInputState();
}

class _PhoneNumberInputState extends State<PhoneNumberInput> {
  String selectedCode = '+92';

  final List<Map<String, String>> countries = [
    {'flag': '🇦🇫', 'code': '+93', 'name': 'Afghanistan'},
    {'flag': '🇦🇺', 'code': '+61', 'name': 'Australia'},
    {'flag': '🇧🇩', 'code': '+880', 'name': 'Bangladesh'},
    {'flag': '🇨🇦', 'code': '+1', 'name': 'Canada'},
    {'flag': '🇨🇳', 'code': '+86', 'name': 'China'},
    {'flag': '🇫🇷', 'code': '+33', 'name': 'France'},
    {'flag': '🇩🇪', 'code': '+49', 'name': 'Germany'},
    {'flag': '🇮🇳', 'code': '+91', 'name': 'India'},
    {'flag': '🇮🇷', 'code': '+98', 'name': 'Iran, Islamic Republic of'},
    {'flag': '🇮🇹', 'code': '+39', 'name': 'Italy'},
    {'flag': '🇯🇵', 'code': '+81', 'name': 'Japan'},
    {'flag': '🇵🇰', 'code': '+92', 'name': 'Pakistan'},
    {'flag': '🇷🇺', 'code': '+7', 'name': 'Russian Federation'},
    {'flag': '🇸🇦', 'code': '+966', 'name': 'Saudi Arabia'},
    {'flag': '🇹🇷', 'code': '+90', 'name': 'Turkey'},
    {'flag': '🇦🇪', 'code': '+971', 'name': 'United Arab Emirates'},
    {'flag': '🇬🇧', 'code': '+44', 'name': 'United Kingdom'},
    {'flag': '🇺🇸', 'code': '+1', 'name': 'United States'},
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        width: 360,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CloudMistColors.textBoss,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Country code dropdown
            DropdownButton<String>(
              value: selectedCode,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down),
              items: countries.map((country) {
                return DropdownMenuItem<String>(
                  value: country['code'],
                  child: Text('${country['flag']} ${country['code']}'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedCode = value;
                  });
                }
              },
            ),
            const SizedBox(width: 10),
            // Phone number field
            const Expanded(
              child: TextField(
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
