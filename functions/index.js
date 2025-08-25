const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Configure Nodemailer with your Gmail account
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'your-email@gmail.com', // Your Gmail address
    pass: 'your-app-specific-password', // Your app-specific password
  },
});

exports.sendOtp = functions.https.onRequest(async (req, res) => {
  const email = req.body.email;
  if (!email) {
    return res.status(400).send('Email is required');
  }

  // Generate 6-digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes expiration

  try {
    // Store OTP in Firestore
    await admin.firestore().collection('otp_verifications').doc(email).set({
      otp,
      expiresAt: expiresAt.toISOString(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send email with OTP
    await transporter.sendMail({
      from: '"Zeus" <admin-zeus@gmail.com>',
      to: email,
      subject: 'Your Verification Code',
      text: `Your verification code is ${otp}. It expires in 5 minutes.`,
      html: `<p>Your verification code is <b>${otp}</b>. It expires in 5 minutes.</p>`,
    });

    res.status(200).send('OTP sent successfully');
  } catch (error) {
    console.error('Error sending OTP:', error);
    res.status(500).send('Failed to send OTP');
  }
});