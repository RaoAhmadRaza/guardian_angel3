/**
 * Guardian Angel - Firebase Cloud Functions
 *
 * Handles:
 * - Chat message notifications
 * - SOS alert notifications
 * - Health alert notifications (arrhythmia, abnormal vitals)
 * - Arrhythmia inference (HTTP endpoint)
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ═══════════════════════════════════════════════════════════════════════════
// CHAT NOTIFICATIONS
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Send chat notification to recipient
 */
exports.sendChatNotification = functions.https.onCall(async (data, context) => {
  // Verify authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be authenticated to send notifications",
    );
  }

  const {
    recipient_uid: recipientUid,
    sender_name: senderName,
    message_preview: messagePreview,
    thread_id: threadId,
    message_id: messageId,
  } = data;

  if (!recipientUid || !senderName) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "recipient_uid and sender_name are required",
    );
  }

  try {
    // Get recipient's FCM tokens
    const tokens = await getTokensForUser(recipientUid);
    if (tokens.length === 0) {
      return {success: true, success_count: 0, failure_count: 0, message: "No tokens"};
    }

    // Build notification
    const notification = {
      title: senderName,
      body: messagePreview || "Sent you a message",
    };

    const payload = {
      notification,
      data: {
        type: "chat",
        sender_id: context.auth.uid,
        thread_id: threadId || "",
        message_id: messageId || "",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "chat_messages",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: "default",
          },
        },
      },
    };

    // Send to all tokens
    const result = await sendToTokens(tokens, payload);
    return result;
  } catch (error) {
    console.error("Error sending chat notification:", error);
    return {success: false, error: error.message};
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// SOS ALERTS
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Send SOS alert to all caregivers and doctors
 */
exports.sendSosAlert = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
  }

  const {
    patient_uid: patientUid,
    patient_name: patientName,
    sos_session_id: sosSessionId,
    recipient_uids: recipientUids,
    location,
    emergency_message: emergencyMessage,
  } = data;

  if (!patientUid || !recipientUids || recipientUids.length === 0) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "patient_uid and recipient_uids are required",
    );
  }

  try {
    // Get all tokens for all recipients
    const allTokens = [];
    for (const uid of recipientUids) {
      const tokens = await getTokensForUser(uid);
      allTokens.push(...tokens);
    }

    if (allTokens.length === 0) {
      console.log("No tokens found for SOS recipients");
      return {success: true, success_count: 0, failure_count: 0};
    }

    // Build high-priority notification
    const notification = {
      title: "🚨 EMERGENCY SOS",
      body: `${patientName || "Patient"} needs immediate help!${location ? ` Location: ${location}` : ""}`,
    };

    const payload = {
      notification,
      data: {
        type: "sos_alert",
        patient_uid: patientUid,
        sos_session_id: sosSessionId || "",
        location: location || "",
        emergency_message: emergencyMessage || "",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        priority: "critical",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "sos_alerts",
          sound: "emergency",
          priority: "max",
          visibility: "public",
        },
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: "critical",
            "interruption-level": "critical",
          },
        },
        headers: {
          "apns-priority": "10",
        },
      },
    };

    const result = await sendToTokens(allTokens, payload);

    // Log SOS notification in Firestore
    await db.collection("sos_sessions").doc(sosSessionId).update({
      notifications_sent: admin.firestore.FieldValue.arrayUnion({
        type: "push",
        sent_at: admin.firestore.FieldValue.serverTimestamp(),
        success_count: result.success_count,
        failure_count: result.failure_count,
      }),
    });

    return result;
  } catch (error) {
    console.error("Error sending SOS alert:", error);
    return {success: false, error: error.message};
  }
});

/**
 * Send SOS response notification (caregiver/doctor responded)
 */
exports.sendSosResponse = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
  }

  const {
    patient_uid: patientUid,
    responder_name: responderName,
    responder_role: responderRole,
    sos_session_id: sosSessionId,
    response_type: responseType,
  } = data;

  try {
    const tokens = await getTokensForUser(patientUid);
    if (tokens.length === 0) {
      return {success: true, success_count: 0};
    }

    const roleDisplay = responderRole === "doctor" ? "Dr." : "";
    let bodyText;
    switch (responseType) {
      case "acknowledged":
        bodyText = `${roleDisplay} ${responderName} acknowledged your SOS`;
        break;
      case "on_my_way":
        bodyText = `${roleDisplay} ${responderName} is on their way to help!`;
        break;
      case "calling":
        bodyText = `${roleDisplay} ${responderName} is calling you`;
        break;
      default:
        bodyText = `${roleDisplay} ${responderName} responded to your SOS`;
    }

    const payload = {
      notification: {
        title: "Help is coming!",
        body: bodyText,
      },
      data: {
        type: responderRole === "doctor" ? "doctor_response" : "caregiver_response",
        sos_session_id: sosSessionId || "",
        response_type: responseType,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "sos_responses",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    return await sendToTokens(tokens, payload);
  } catch (error) {
    console.error("Error sending SOS response:", error);
    return {success: false, error: error.message};
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// HEALTH ALERTS
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Send health alert (arrhythmia, abnormal vitals)
 */
exports.sendHealthAlert = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
  }

  const {
    patient_uid: patientUid,
    patient_name: patientName,
    alert_type: alertType,
    alert_message: alertMessage,
    recipient_uids: recipientUids,
    alert_id: alertId,
    priority,
  } = data;

  if (!recipientUids || recipientUids.length === 0) {
    return {success: true, success_count: 0};
  }

  try {
    const allTokens = [];
    for (const uid of recipientUids) {
      const tokens = await getTokensForUser(uid);
      allTokens.push(...tokens);
    }

    if (allTokens.length === 0) {
      return {success: true, success_count: 0};
    }

    // Build notification based on alert type
    let title;
    switch (alertType) {
      case "arrhythmia":
        title = "⚠️ Arrhythmia Detected";
        break;
      case "high_heart_rate":
        title = "💓 High Heart Rate Alert";
        break;
      case "low_oxygen":
        title = "🫁 Low Oxygen Alert";
        break;
      default:
        title = "Health Alert";
    }

    const payload = {
      notification: {
        title,
        body: `${patientName || "Patient"}: ${alertMessage}`,
      },
      data: {
        type: "health_alert",
        alert_type: alertType,
        patient_uid: patientUid,
        alert_id: alertId || "",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: priority === "high" ? "high" : "normal",
        notification: {
          channelId: "health_alerts",
          sound: priority === "high" ? "alert" : "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: priority === "high" ? "critical" : "default",
          },
        },
      },
    };

    const result = await sendToTokens(allTokens, payload);

    // Store alert in Firestore
    if (alertId) {
      await db.collection("patients").doc(patientUid).collection("health_alerts").doc(alertId).update({
        notification_sent_at: admin.firestore.FieldValue.serverTimestamp(),
        notification_success_count: result.success_count,
      });
    }

    return result;
  } catch (error) {
    console.error("Error sending health alert:", error);
    return {success: false, error: error.message};
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// ARRHYTHMIA INFERENCE (HTTP Endpoint)
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Arrhythmia inference endpoint
 * Replaces the localhost Python service with a cloud-hosted alternative
 *
 * This uses a simplified rule-based detection. For production,
 * integrate with a proper ML model (e.g., Vertex AI, TensorFlow Serving)
 */
exports.analyzeArrhythmia = functions.https.onRequest(async (req, res) => {
  // CORS
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({error: "Method not allowed"});
    return;
  }

  try {
    const {rr_intervals_ms: rrIntervals, request_id: requestId} = req.body;

    if (!rrIntervals || !Array.isArray(rrIntervals) || rrIntervals.length < 10) {
      res.status(400).json({
        error: "rr_intervals_ms must be an array with at least 10 values",
      });
      return;
    }

    // Calculate HRV features
    const features = calculateHRVFeatures(rrIntervals);

    // Rule-based arrhythmia detection
    // In production, replace with actual ML model inference
    const analysis = analyzeForArrhythmia(features);

    res.status(200).json({
      request_id: requestId || "unknown",
      risk_score: analysis.riskScore,
      risk_level: analysis.riskLevel,
      classification: analysis.classification,
      confidence: analysis.confidence,
      features: {
        mean_rr: features.meanRR,
        sdnn: features.sdnn,
        rmssd: features.rmssd,
        pnn50: features.pNN50,
        heart_rate_bpm: features.heartRateBpm,
      },
      analyzed_at: new Date().toISOString(),
      model_version: "1.0.0-cloud",
    });
  } catch (error) {
    console.error("Arrhythmia analysis error:", error);
    res.status(500).json({error: error.message});
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// TWILIO SMS & CALL - AUTOMATIC SENDING
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Twilio client initialization
 * Credentials should be set via Firebase Functions Config:
 *   firebase functions:config:set twilio.account_sid="ACXXX" twilio.auth_token="XXX" twilio.phone_number="+1234567890"
 */
let twilioClient = null;

function getTwilioClient() {
  if (twilioClient) return twilioClient;
  
  const accountSid = functions.config().twilio?.account_sid;
  const authToken = functions.config().twilio?.auth_token;
  
  if (!accountSid || !authToken) {
    console.warn("Twilio credentials not configured. SMS/Call will be simulated.");
    return null;
  }
  
  const twilio = require("twilio");
  twilioClient = twilio(accountSid, authToken);
  return twilioClient;
}

function getTwilioPhoneNumber() {
  return functions.config().twilio?.phone_number || null;
}

/**
 * Send SOS SMS to emergency contacts
 * Automatically sends SMS without user interaction
 */
exports.sendSosSms = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
  }

  const {
    patient_uid: patientUid,
    patient_name: patientName,
    sos_session_id: sosSessionId,
    contacts,
    location,
    emergency_message: emergencyMessage,
  } = data;

  if (!patientUid || !contacts || contacts.length === 0) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "patient_uid and contacts are required",
    );
  }

  const client = getTwilioClient();
  const fromNumber = getTwilioPhoneNumber();

  // Build message
  let locationStr = "";
  if (location) {
    locationStr = `\nLocation: https://maps.google.com/?q=${location}`;
  }

  const message = emergencyMessage || 
    `🚨 EMERGENCY SOS: ${patientName || "Patient"} needs immediate help!${locationStr}\n\nThis is an automated alert from Guardian Angel.`;

  const results = [];
  let successCount = 0;
  let failureCount = 0;

  for (const contact of contacts) {
    const phoneNumber = contact.phone_number || contact.phoneNumber;
    if (!phoneNumber) continue;

    try {
      if (client && fromNumber) {
        // Real Twilio SMS
        const twilioResult = await client.messages.create({
          body: message,
          from: fromNumber,
          to: phoneNumber,
        });
        
        console.log(`SMS sent to ${phoneNumber}: ${twilioResult.sid}`);
        results.push({
          phone: phoneNumber,
          success: true,
          message_sid: twilioResult.sid,
        });
        successCount++;
      } else {
        // Simulation mode (Twilio not configured)
        console.log(`[SIMULATED] SMS to ${phoneNumber}: ${message}`);
        results.push({
          phone: phoneNumber,
          success: true,
          simulated: true,
        });
        successCount++;
      }
    } catch (error) {
      console.error(`Failed to send SMS to ${phoneNumber}:`, error.message);
      results.push({
        phone: phoneNumber,
        success: false,
        error: error.message,
      });
      failureCount++;
    }
  }

  // Log SMS activity in Firestore
  if (sosSessionId) {
    try {
      await db.collection("sos_sessions").doc(sosSessionId).update({
        sms_notifications: admin.firestore.FieldValue.arrayUnion({
          sent_at: admin.firestore.FieldValue.serverTimestamp(),
          success_count: successCount,
          failure_count: failureCount,
          contacts_count: contacts.length,
        }),
      });
    } catch (e) {
      console.warn("Failed to log SMS to session:", e.message);
    }
  }

  return {
    success: successCount > 0,
    success_count: successCount,
    failure_count: failureCount,
    results,
    twilio_configured: !!(client && fromNumber),
  };
});

/**
 * Initiate SOS phone call to emergency services
 * Uses Twilio to place automated call
 */
exports.sendSosCall = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");
  }

  const {
    patient_uid: patientUid,
    patient_name: patientName,
    sos_session_id: sosSessionId,
    emergency_number: emergencyNumber,
    location,
  } = data;

  if (!patientUid || !emergencyNumber) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "patient_uid and emergency_number are required",
    );
  }

  const client = getTwilioClient();
  const fromNumber = getTwilioPhoneNumber();

  // Build TwiML for the call - announces emergency message
  const locationStr = location ? `Their location is ${location.replace(",", " ")}` : "";
  const twimlMessage = `
    <Response>
      <Say voice="alice">
        Emergency alert from Guardian Angel Health App.
        Patient ${patientName || "unknown"} needs immediate assistance.
        ${locationStr}
        This is an automated emergency call. Please dispatch help immediately.
      </Say>
      <Pause length="2"/>
      <Say voice="alice">
        Repeating: Patient ${patientName || "unknown"} needs immediate assistance.
        ${locationStr}
      </Say>
    </Response>
  `;

  try {
    if (client && fromNumber) {
      // Real Twilio call
      const call = await client.calls.create({
        twiml: twimlMessage,
        from: fromNumber,
        to: emergencyNumber,
      });

      console.log(`Emergency call placed to ${emergencyNumber}: ${call.sid}`);

      // Log call in Firestore
      if (sosSessionId) {
        await db.collection("sos_sessions").doc(sosSessionId).update({
          emergency_calls: admin.firestore.FieldValue.arrayUnion({
            call_sid: call.sid,
            number: emergencyNumber,
            placed_at: admin.firestore.FieldValue.serverTimestamp(),
            status: "initiated",
          }),
          emergency_call_placed: true,
        });
      }

      return {
        success: true,
        call_sid: call.sid,
        number: emergencyNumber,
        twilio_configured: true,
      };
    } else {
      // Simulation mode
      console.log(`[SIMULATED] Emergency call to ${emergencyNumber}`);
      console.log(`[SIMULATED] Message: Patient ${patientName} needs help at ${location}`);

      if (sosSessionId) {
        await db.collection("sos_sessions").doc(sosSessionId).update({
          emergency_calls: admin.firestore.FieldValue.arrayUnion({
            number: emergencyNumber,
            placed_at: admin.firestore.FieldValue.serverTimestamp(),
            status: "simulated",
            simulated: true,
          }),
        });
      }

      return {
        success: true,
        simulated: true,
        number: emergencyNumber,
        twilio_configured: false,
        message: "Call simulated - Twilio not configured",
      };
    }
  } catch (error) {
    console.error(`Failed to place emergency call to ${emergencyNumber}:`, error.message);

    if (sosSessionId) {
      await db.collection("sos_sessions").doc(sosSessionId).update({
        emergency_calls: admin.firestore.FieldValue.arrayUnion({
          number: emergencyNumber,
          placed_at: admin.firestore.FieldValue.serverTimestamp(),
          status: "failed",
          error: error.message,
        }),
      });
    }

    return {
      success: false,
      error: error.message,
      number: emergencyNumber,
    };
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Get FCM tokens for a user
 */
async function getTokensForUser(uid) {
  try {
    const doc = await db.collection("users").doc(uid).get();
    if (!doc.exists) return [];

    const data = doc.data();
    const tokens = data.fcm_tokens || [];
    return tokens.map((t) => t.token).filter((t) => t);
  } catch (error) {
    console.error(`Error getting tokens for ${uid}:`, error);
    return [];
  }
}

/**
 * Send notification to multiple tokens
 */
async function sendToTokens(tokens, payload) {
  if (tokens.length === 0) {
    return {success: true, success_count: 0, failure_count: 0};
  }

  const messages = tokens.map((token) => ({
    ...payload,
    token,
  }));

  try {
    const response = await messaging.sendEach(messages);

    const successCount = response.successCount;
    const failureCount = response.failureCount;

    // Handle failed tokens (remove stale tokens)
    if (failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const error = resp.error;
          if (
            error?.code === "messaging/invalid-registration-token" ||
            error?.code === "messaging/registration-token-not-registered"
          ) {
            failedTokens.push(tokens[idx]);
          }
        }
      });

      // Remove stale tokens (fire-and-forget)
      if (failedTokens.length > 0) {
        console.log("Removing stale tokens:", failedTokens.length);
        // In production, remove these tokens from Firestore
      }
    }

    return {
      success: true,
      success_count: successCount,
      failure_count: failureCount,
    };
  } catch (error) {
    console.error("Error sending to tokens:", error);
    return {success: false, error: error.message};
  }
}

/**
 * Calculate HRV features from RR intervals
 */
function calculateHRVFeatures(rrIntervals) {
  const n = rrIntervals.length;

  // Mean RR
  const meanRR = rrIntervals.reduce((a, b) => a + b, 0) / n;

  // SDNN (Standard Deviation of NN intervals)
  const squaredDiffs = rrIntervals.map((rr) => Math.pow(rr - meanRR, 2));
  const sdnn = Math.sqrt(squaredDiffs.reduce((a, b) => a + b, 0) / n);

  // RMSSD (Root Mean Square of Successive Differences)
  const successiveDiffs = [];
  for (let i = 1; i < n; i++) {
    successiveDiffs.push(rrIntervals[i] - rrIntervals[i - 1]);
  }
  const squaredSuccDiffs = successiveDiffs.map((d) => Math.pow(d, 2));
  const rmssd = Math.sqrt(squaredSuccDiffs.reduce((a, b) => a + b, 0) / successiveDiffs.length);

  // pNN50 (Percentage of successive differences > 50ms)
  const nn50Count = successiveDiffs.filter((d) => Math.abs(d) > 50).length;
  const pNN50 = (nn50Count / successiveDiffs.length) * 100;

  // Heart rate
  const heartRateBpm = 60000 / meanRR;

  return {
    meanRR,
    sdnn,
    rmssd,
    pNN50,
    heartRateBpm,
  };
}

/**
 * Analyze HRV features for arrhythmia indicators
 * This is a simplified rule-based analysis
 * Production should use trained ML model
 */
function analyzeForArrhythmia(features) {
  let riskScore = 0;
  const flags = [];

  // High variability can indicate arrhythmia
  if (features.sdnn > 200) {
    riskScore += 0.3;
    flags.push("high_variability");
  }

  // Very low variability can indicate issues
  if (features.sdnn < 20) {
    riskScore += 0.2;
    flags.push("low_variability");
  }

  // High RMSSD deviation
  if (features.rmssd > 150) {
    riskScore += 0.25;
    flags.push("high_rmssd");
  }

  // Abnormal pNN50
  if (features.pNN50 > 50 || features.pNN50 < 3) {
    riskScore += 0.15;
    flags.push("abnormal_pnn50");
  }

  // Extreme heart rate
  if (features.heartRateBpm > 150 || features.heartRateBpm < 40) {
    riskScore += 0.3;
    flags.push("extreme_heart_rate");
  }

  // Cap at 1.0
  riskScore = Math.min(riskScore, 1.0);

  // Determine risk level
  let riskLevel;
  let classification;
  if (riskScore >= 0.7) {
    riskLevel = "high";
    classification = "Potential Arrhythmia";
  } else if (riskScore >= 0.4) {
    riskLevel = "moderate";
    classification = "Irregular Pattern";
  } else {
    riskLevel = "low";
    classification = "Normal Sinus Rhythm";
  }

  return {
    riskScore,
    riskLevel,
    classification,
    confidence: 0.75 + (0.25 * (1 - riskScore)), // Higher confidence for normal
    flags,
  };
}
