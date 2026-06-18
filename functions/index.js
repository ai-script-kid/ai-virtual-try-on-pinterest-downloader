const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");
const fetch = require("node-fetch");
const FormData = require("form-data");

admin.initializeApp();
const db = admin.firestore();
// v2 gen2

const RAPIDAPI_KEY = "RAPIDAPI_KEY_HERE";
const RAPIDAPI_HOST = "pinterest-downloader-download-pinterest-image-video-and-reels.p.rapidapi.com";
const WIRO_API_KEY = "WIRO_API_KEY_HERE";
const WIRO_API_SECRET = "WIRO_API_SECRET_HERE";

function wiroAuth() {
    const nonce = Date.now().toString();
    const hmac = crypto.createHmac("sha256", WIRO_API_KEY);
    hmac.update(WIRO_API_SECRET + nonce);
    const signature = hmac.digest("hex");
    return { nonce, signature };
}

// downloadPin
exports.downloadPin = onCall(
    { timeoutSeconds: 60, memory: "256MiB" },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "Authentication required");
        }

        const { pinUrl } = request.data;
        const uid = request.auth.uid;

        if (!pinUrl || !pinUrl.includes("pinterest.com")) {
            throw new HttpsError("invalid-argument", "Invalid Pinterest URL");
        }

        // Check download count against subscription
        const downloadsSnap = await db.collection("users").doc(uid).collection("downloads").get();
        const downloadCount = downloadsSnap.size;

        if (downloadCount >= 1) {
            const userDoc = await db.collection("users").doc(uid).get();
            const isPremium = userDoc.exists && userDoc.data().isPremium === true;
            if (!isPremium) {
                throw new HttpsError("permission-denied", "subscription_required");
            }
        }

        // Call Pinterest RapidAPI
        const response = await fetch(
            `https://${RAPIDAPI_HOST}/pins?url=${encodeURIComponent(pinUrl)}`,
            {
                method: "GET",
                headers: {
                    "x-rapidapi-host": RAPIDAPI_HOST,
                    "x-rapidapi-key": RAPIDAPI_KEY,
                    "Content-Type": "application/json",
                },
            }
        );

        if (!response.ok) {
            throw new HttpsError("internal", `Pinterest API error: ${response.status}`);
        }

        const json = await response.json();

        if (json.status !== "success" || !json.data) {
            throw new HttpsError("not-found", "Pin not found or not accessible");
        }

        const pinData = json.data;

        let imageUrl = null;
        let videoUrl = null;
        let thumbnailUrl = "";
        let isVideo = false;

        const storyBlock = pinData.story_pin_data?.pages?.[0]?.blocks?.[0];
        if (storyBlock?.type === "story_pin_video_block" && storyBlock.video) {
            isVideo = true;
            videoUrl = storyBlock.video.video_list?.V_HLSV3_MOBILE?.url || null;
            thumbnailUrl = storyBlock.video.video_list?.V_HLSV3_MOBILE?.thumbnail || "";
        }

        if (!isVideo && pinData.videos?.video_list) {
            isVideo = true;
            const vList = pinData.videos.video_list;
            const preferred = vList.V_720P || vList.V_480P || Object.values(vList)[0];
            videoUrl = preferred?.url || null;
        }

        if (pinData.images?.orig?.url) {
            imageUrl = pinData.images.orig.url;
        } else if (pinData.images?.["736x"]?.url) {
            imageUrl = pinData.images["736x"].url;
        }

        if (!thumbnailUrl) {
            thumbnailUrl =
                pinData.images?.["736x"]?.url ||
                pinData.images?.["474x"]?.url ||
                pinData.image_medium_url ||
                imageUrl ||
                "";
        }

        const title = pinData.title || pinData.grid_title || null;
        const docRef = db.collection("users").doc(uid).collection("downloads").doc();

        await docRef.set({
            pinUrl,
            imageUrl,
            videoUrl,
            thumbnailUrl,
            isVideo,
            title,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return { id: docRef.id, imageUrl, videoUrl, thumbnailUrl, isVideo, title };
    }
);

// tryOn
exports.tryOn = onCall(
    { timeoutSeconds: 180, memory: "512MiB" },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "Authentication required");
        }

        const { clothingImageUrl, userImageBase64 } = request.data;
        const uid = request.auth.uid;
        const userRef = db.collection("users").doc(uid);

        // Atomically check isPremium + deduct 1 credit
        await db.runTransaction(async (tx) => {
            const snap = await tx.get(userRef);
            const data = snap.data() || {};
            if (!data.isPremium) {
                throw new HttpsError("permission-denied", "subscription_required");
            }
            const credits = typeof data.tryOnCredits === "number" ? data.tryOnCredits : 0;
            if (credits <= 0) {
                throw new HttpsError("permission-denied", "credits_exhausted");
            }
            tx.update(userRef, { tryOnCredits: admin.firestore.FieldValue.increment(-1) });
        });

        const userBuffer = Buffer.from(userImageBase64, "base64");

        const { nonce, signature } = wiroAuth();

        const form = new FormData();
        form.append("inputImage", userBuffer, { filename: "person.jpg", contentType: "image/jpeg" });
        form.append("inputImage", clothingImageUrl);
        form.append(
            "prompt",
            "Virtually try on the clothing or item from the second image on the person shown in the first image. " +
            "Keep the person's face, skin tone, hair, and body proportions exactly the same. " +
            "The result should look photorealistic and natural, as if the person is actually wearing the item."
        );
        form.append("aspectRatio", "");
        form.append("resolution", "1K");
        form.append("safetySetting", "OFF");

        const runResponse = await fetch("https://api.wiro.ai/v1/Run/google/nano-banana-2", {
            method: "POST",
            headers: {
                "x-api-key": WIRO_API_KEY,
                "x-nonce": nonce,
                "x-signature": signature,
                ...form.getHeaders(),
            },
            body: form,
        });

        const runResult = await runResponse.json();
        if (!runResult.result || !runResult.taskid) {
            // Refund the credit since we never submitted successfully
            await userRef.update({ tryOnCredits: admin.firestore.FieldValue.increment(1) });
            throw new HttpsError("internal", `Wiro API error: ${JSON.stringify(runResult.errors)}`);
        }

        const taskId = runResult.taskid;

        // Poll for result (max 50 × 3s = 150s)
        let resultUrl = null;
        for (let attempt = 0; attempt < 50; attempt++) {
            await new Promise((resolve) => setTimeout(resolve, 3000));

            const { nonce: n2, signature: s2 } = wiroAuth();
            const detailForm = new FormData();
            detailForm.append("taskid", taskId);

            const detailResponse = await fetch("https://api.wiro.ai/v1/Task/Detail", {
                method: "POST",
                headers: {
                    "x-api-key": WIRO_API_KEY,
                    "x-nonce": n2,
                    "x-signature": s2,
                    ...detailForm.getHeaders(),
                },
                body: detailForm,
            });

            const detail = await detailResponse.json();
            const task = detail.tasklist?.[0];
            if (!task) continue;

            if (task.status === "task_postprocess_end") {
                resultUrl = task.outputs?.[0]?.url || null;
                break;
            }
            if (task.status === "task_cancel") {
                throw new HttpsError("internal", "Try-on task was cancelled");
            }
        }

        if (!resultUrl) {
            throw new HttpsError("deadline-exceeded", "Try-on processing timed out");
        }

        const docRef = db.collection("users").doc(uid).collection("tryons").doc();
        await docRef.set({
            clothingImageUrl,
            resultUrl,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return { resultUrl, id: docRef.id };
    }
);

// revenuecatWebhook
const RC_WEBHOOK_SECRET = "REVENUECAT_WEBHOOK_SECRET_HERE";

const PRODUCT_CREDITS = { pinweekly: 20, pinyearly: 300 };

// Events that grant/renew access — reset credits for purchase/renewal
const CREDIT_RESET_EVENTS = new Set(["INITIAL_PURCHASE", "RENEWAL", "SUBSCRIPTION_EXTENDED"]);
// Access restored but don't reset remaining credits
const REACTIVATE_EVENTS = new Set(["UNCANCELLATION", "NON_SUBSCRIPTION_PURCHASE"]);
const INACTIVE_EVENTS = new Set(["EXPIRATION", "BILLING_ISSUE"]);

exports.revenuecatWebhook = onRequest(async (req, res) => {
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }

    const authHeader = req.headers["authorization"] || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : authHeader;
    if (token !== RC_WEBHOOK_SECRET) {
        res.status(401).send("Unauthorized");
        return;
    }

    const event = req.body?.event;
    if (!event || !event.type || !event.app_user_id) {
        res.status(400).send("Bad Request");
        return;
    }

    const uid = event.app_user_id;
    const userRef = db.collection("users").doc(uid);

    if (CREDIT_RESET_EVENTS.has(event.type)) {
        const credits = PRODUCT_CREDITS[event.product_id] ?? 0;
        await userRef.set({ isPremium: true, tryOnCredits: credits }, { merge: true });
    } else if (REACTIVATE_EVENTS.has(event.type)) {
        await userRef.set({ isPremium: true }, { merge: true });
    } else if (INACTIVE_EVENTS.has(event.type)) {
        await userRef.set({ isPremium: false, tryOnCredits: 0 }, { merge: true });
    }

    res.status(200).send("OK");
});

// updateSubscriptionStatus
exports.updateSubscriptionStatus = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
    }

    const { isPremium } = request.data;
    const uid = request.auth.uid;

    await db.collection("users").doc(uid).set({ isPremium: Boolean(isPremium) }, { merge: true });

    return { success: true };
});
