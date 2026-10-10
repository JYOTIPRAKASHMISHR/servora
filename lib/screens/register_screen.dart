import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:servora/services/auth_service.dart';

import '../widgets/servora_logo.dart';
import '../widgets/custom_textfield.dart';

import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final jobController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final AuthService authService = AuthService();

  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool loading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    jobController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void register() async {
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    if(password != confirmPassword){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password and Confirm Password must be same"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      loading = true;
    });

    bool result = await authService.registerUser(
      name:nameController.text.trim(),
      email:emailController.text.trim(),
      phone:phoneController.text.trim(),
      job:jobController.text.trim(),
      password:password,
    );

    setState(() {
      loading = false;
    });
    if(result){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration Successful"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:(context)=>LoginScreen(),
        ),
      );
    }
    else{
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration Failed"),
          backgroundColor: Colors.red,
        ),
      );
    }
    

    // Firebase registration
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors:[
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
              horizontal:25,
              vertical:25,
            ),

            child: Column(
              children:[

                ZoomIn(
                  duration: const Duration(seconds:2),
                  child: const ServoraLogo(
                    size:100,
                  ),
                ),

                const SizedBox(height:15),

                FadeInDown(
                  child: const Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize:32,
                      fontWeight:FontWeight.bold,
                      color:Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height:8),

                const Text(
                  "Join Servora and get things done",
                  style:TextStyle(
                    color:Colors.white70,
                    fontSize:15,
                  ),
                ),

                const SizedBox(height:30),

                FadeInUp(
                  duration:const Duration(seconds:2),

                  child:Container(
                    padding:const EdgeInsets.all(22),

                    decoration:BoxDecoration(
                      color:Colors.white.withOpacity(.12),
                      borderRadius:BorderRadius.circular(30),
                      border:Border.all(
                        color:Colors.white24,
                      ),
                    ),

                    child:Column(
                      children:[

                        CustomTextField(
                          hint:"Full Name",
                          icon:Icons.person_outline,
                          controller:nameController,
                        ),

                        const SizedBox(height:15),

                        CustomTextField(
                          hint:"Email Address",
                          icon:Icons.email_outlined,
                          controller:emailController,
                        ),

                        const SizedBox(height:15),

                        CustomTextField(
                          hint:"Phone Number",
                          icon:Icons.phone_android,
                          controller:phoneController,
                        ),

                        const SizedBox(height:15),

                        CustomTextField(
                          hint:"Current Job / Profession",
                          icon:Icons.work_outline,
                          controller:jobController,
                        ),

                        const SizedBox(height:15),

                        passwordField(
                          controller:passwordController,
                          hint:"Password",
                          hide:hidePassword,
                          onTap:(){
                            setState(() {
                              hidePassword=!hidePassword;
                            });
                          },
                        ),

                        const SizedBox(height:15),

                        passwordField(
                          controller:confirmPasswordController,
                          hint:"Confirm Password",
                          hide:hideConfirmPassword,
                          onTap:(){
                            setState(() {
                              hideConfirmPassword=!hideConfirmPassword;
                            });
                          },
                        ),

                        const SizedBox(height:30),

                        SizedBox(
                          width:double.infinity,
                          height:55,

                          child:ElevatedButton(
                            style:ElevatedButton.styleFrom(
                              backgroundColor:
                              const Color(0xff2563EB),

                              shape:RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(18),
                              ),
                            ),

                            onPressed:register,

                            child:loading
                            ? const CircularProgressIndicator(
                                color:Colors.white,
                              )
                            : const Text(
                                "Register",
                                style:TextStyle(
                                  fontSize:18,
                                  fontWeight:FontWeight.bold,
                                  color:Colors.white,
                                ),
                              ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height:25),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,

                  children:[

                    const Text(
                      "Already have account? ",
                      style:
                      TextStyle(
                        color:Colors.white70,
                      ),
                    ),

                    GestureDetector(
                      onTap:(){
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder:(context)=>
                            LoginScreen(),
                          ),
                        );
                      },

                      child:const Text(
                        "Login",
                        style:TextStyle(
                          color:Color(0xff38BDF8),
                          fontWeight:FontWeight.bold,
                          fontSize:16,
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


  Widget passwordField({
    required TextEditingController controller,
    required String hint,
    required bool hide,
    required VoidCallback onTap,
  }){

    return TextField(
      controller:controller,
      obscureText:hide,

      style:const TextStyle(
        color:Colors.white,
      ),

      decoration:InputDecoration(
        hintText:hint,

        hintStyle:
        const TextStyle(
          color:Colors.white54,
        ),

        prefixIcon:
        const Icon(
          Icons.lock_outline,
          color:Colors.white,
        ),

        suffixIcon:IconButton(
          icon:Icon(
            hide
            ? Icons.visibility_off
            : Icons.visibility,

            color:Colors.white,
          ),

          onPressed:onTap,
        ),

        filled:true,

        fillColor:
        Colors.white.withOpacity(.15),

        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(18),

          borderSide:
          BorderSide.none,
        ),
      ),
    );
  }
}