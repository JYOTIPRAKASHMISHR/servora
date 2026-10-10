const { setGlobalOptions } = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const Razorpay = require("razorpay");

setGlobalOptions({
  maxInstances: 10,
});


// ==========================================
// RAZORPAY ORDER CREATION
// ==========================================

exports.createRazorpayOrder = onRequest(
  {
    region: "asia-south1",
    cors: true,
  },

  async (req, res) => {

    try {

      // --------------------------------------
      // Only POST requests are allowed
      // --------------------------------------

      if (req.method !== "POST") {

        return res.status(405).json({
          success: false,
          message: "Only POST requests are allowed",
        });

      }


      // --------------------------------------
      // Get amount from Flutter
      // --------------------------------------

      const { amount } = req.body;


      // --------------------------------------
      // Validate amount
      // --------------------------------------

      if (!amount) {

        return res.status(400).json({
          success: false,
          message: "Amount is required",
        });

      }


      const amountInRupees = Number(amount);


      if (
        !Number.isFinite(amountInRupees) ||
        amountInRupees <= 0
      ) {

        return res.status(400).json({
          success: false,
          message: "Invalid amount",
        });

      }


      // --------------------------------------
      // Razorpay amount must be in paise
      //
      // ₹699 = 69900 paise
      // ₹199 = 19900 paise
      // --------------------------------------

      const amountInPaise =
          Math.round(amountInRupees * 100);


      // --------------------------------------
      // Razorpay instance
      //
      // IMPORTANT:
      // We will NOT hard-code the secret here.
      // --------------------------------------

      const razorpay = new Razorpay({

        key_id:
            process.env.RAZORPAY_KEY_ID,

        key_secret:
            process.env.RAZORPAY_KEY_SECRET,

      });


      // --------------------------------------
      // Create Razorpay Order
      // --------------------------------------

      const order =
          await razorpay.orders.create({

        amount: amountInPaise,

        currency: "INR",

        receipt:
            `servora_${Date.now()}`,

      });


      // --------------------------------------
      // Send order information to Flutter
      // --------------------------------------

      return res.status(200).json({

        success: true,

        orderId:
            order.id,

        amount:
            order.amount,

        currency:
            order.currency,

      });

    }

    catch (error) {

      logger.error(
        "Razorpay order creation failed",
        error
      );


      return res.status(500).json({

        success: false,

        message:
            "Unable to create Razorpay order",

      });

    }

  }
);