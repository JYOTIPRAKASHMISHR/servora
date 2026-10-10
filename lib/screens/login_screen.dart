import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:servora/screens/role_screen.dart';
import 'package:servora/services/notification_listener_service.dart';
import 'package:servora/services/notification_service.dart';

import '../services/auth_service.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/servora_logo.dart';


import 'register_screen.dart';


class LoginScreen extends StatefulWidget {

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();

}


class _LoginScreenState extends State<LoginScreen> {


  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService authService = AuthService();

  bool loading = false;
  bool hidePassword = true;


  @override
  void dispose() {

    emailController.dispose();
    passwordController.dispose();

    super.dispose();

  }



  Future<void> login() async {


setState(() {
  loading = true;
});


final user = await authService.loginUser(

  email: emailController.text.trim(),

  password: passwordController.text.trim(),

);



if(user != null){


  // SAVE FCM TOKEN HERE
  await NotificationService.saveToken();
  NotificationListenerService.startListening();

  if (!mounted) return;


  setState(() {
    loading = false;
  });



  Navigator.pushReplacement(

    context,

    MaterialPageRoute(

      builder: (context) =>
          const RoleScreen(),

    ),

  );


}

else{


setState(() {
  loading = false;
});


ScaffoldMessenger.of(context)
.showSnackBar(

const SnackBar(

content:
Text(
"Invalid Email or Password"
),

backgroundColor:
Colors.red,

),

);


}



}

  @override
  Widget build(BuildContext context) {


    return Scaffold(

      body: Container(

        height: double.infinity,
        width: double.infinity,


        decoration: const BoxDecoration(

          gradient: LinearGradient(

            colors: [

              Color(0xff020617),
              Color(0xff062B70),
              Color(0xff0047AB),

            ],

            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,

          ),

        ),



        child: SafeArea(

          child: SingleChildScrollView(

            padding: const EdgeInsets.symmetric(
              horizontal: 25,
              vertical: 35,
            ),



            child: Column(

              children: [


                ZoomIn(

                  duration:
                  const Duration(seconds: 2),

                  child: const ServoraLogo(
                    size: 120,
                  ),

                ),



                const SizedBox(height: 20),



                FadeInDown(

                  child: const Text(

                    "Welcome Back 👋",

                    style: TextStyle(

                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,

                    ),

                  ),

                ),



                const SizedBox(height: 8),



                const Text(

                  "Login to your Servora account",

                  style: TextStyle(

                    color: Colors.white70,
                    fontSize: 16,

                  ),

                ),



                const SizedBox(height: 40),




                FadeInUp(

                  child: Container(

                    padding: const EdgeInsets.all(22),


                    decoration: BoxDecoration(

                      color: Colors.white.withOpacity(0.12),

                      borderRadius:
                      BorderRadius.circular(30),


                      border: Border.all(

                        color: Colors.white24,

                      ),

                    ),



                    child: Column(

                      children: [


                        CustomTextField(

                          hint: "Email Address",

                          icon: Icons.email_outlined,

                          controller: emailController,

                        ),



                        const SizedBox(height: 15),



                        TextField(

                          controller: passwordController,

                          obscureText: hidePassword,


                          style: const TextStyle(

                            color: Colors.white,

                          ),



                          decoration: InputDecoration(


                            hintText: "Password",


                            hintStyle: const TextStyle(

                              color: Colors.white54,

                            ),


                            prefixIcon: const Icon(

                              Icons.lock_outline,

                              color: Colors.white,

                            ),



                            suffixIcon: IconButton(

                              icon: Icon(

                                hidePassword

                                    ? Icons.visibility_off

                                    : Icons.visibility,

                                color: Colors.white,

                              ),


                              onPressed: (){

                                setState((){

                                  hidePassword =
                                  !hidePassword;

                                });

                              },

                            ),



                            filled: true,

                            fillColor:
                            Colors.white.withOpacity(0.15),



                            border: OutlineInputBorder(

                              borderRadius:
                              BorderRadius.circular(18),


                              borderSide:
                              BorderSide.none,

                            ),

                          ),

                        ),



                        const SizedBox(height: 30),



                        SizedBox(

                          width: double.infinity,

                          height: 55,


                          child: ElevatedButton(


                            style:
                            ElevatedButton.styleFrom(

                              backgroundColor:
                              const Color(0xff2563EB),


                              shape:
                              RoundedRectangleBorder(

                                borderRadius:
                                BorderRadius.circular(18),

                              ),

                            ),



                            onPressed: login,



                            child: loading

                                ? const CircularProgressIndicator(

                                    color: Colors.white,

                                  )

                                : const Text(

                                    "Login",

                                    style: TextStyle(

                                      fontSize: 18,

                                      fontWeight:
                                      FontWeight.bold,

                                      color:
                                      Colors.white,

                                    ),

                                  ),

                          ),

                        ),

                      ],

                    ),

                  ),

                ),



                const SizedBox(height: 25),



                Row(

                  mainAxisAlignment:
                  MainAxisAlignment.center,


                  children: [


                    const Text(

                      "Don't have an account? ",

                      style: TextStyle(

                        color: Colors.white70,

                      ),

                    ),



                    GestureDetector(

                      onTap: (){


                        Navigator.push(

                          context,

                          MaterialPageRoute(

                            builder: (context) =>
                            const RegisterScreen(),

                          ),

                        );


                      },


                      child: const Text(

                        "Register",

                        style: TextStyle(

                          color:
                          Color(0xff38BDF8),

                          fontWeight:
                          FontWeight.bold,

                          fontSize: 16,

                        ),

                      ),

                    ),

                  ],

                ),


              ],

            ),

          ),

        ),

      ),

    );

  }

}