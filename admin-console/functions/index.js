const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions/v2");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {initializeApp} = require("firebase-admin/app");

initializeApp();

const db = () => getFirestore();
const auth = () => getAuth();

/**
 * Throws unless the caller is signed in AND has the `admin: true` custom
 * claim. Every function in this file is an admin-only operation.
 */
function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  if (request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Admin privileges required.");
  }
}

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

exports.createUser = onCall(async (request) => {
  requireAdmin(request);

  const {email, password, firstName, lastName, address, contact} =
    request.data || {};
  if (!email || !password || !firstName || !lastName) {
    throw new HttpsError(
      "invalid-argument",
      "Missing required fields: email, password, firstName, lastName."
    );
  }

  let userRecord;
  try {
    userRecord = await auth().createUser({email, password});

    // If the Firestore write fails, roll back the Auth user so we don't
    // leave an orphaned account.
    await db().collection("users").doc(userRecord.uid).set({
      first_name: firstName,
      last_name: lastName,
      contact_number: contact || "",
      address: address || "",
      registration_date: FieldValue.serverTimestamp(),
      uid: userRecord.uid,
    });

    return {success: true, uid: userRecord.uid};
  } catch (error) {
    if (userRecord) {
      await auth().deleteUser(userRecord.uid).catch(() => {});
    }
    logger.error("createUser failed", {code: error.code});
    throw new HttpsError("internal", "Failed to create user.");
  }
});

exports.listUsers = onCall(async (request) => {
  requireAdmin(request);

  try {
    const fetched = await auth().listUsers();
    // Skip admin accounts (by claim) so they don't show in the farmer list.
    const farmers = fetched.users.filter(
      (u) => u.customClaims?.admin !== true
    );

    // Batch-read profile docs instead of one get() per user.
    const refs = farmers.map((u) => db().collection("users").doc(u.uid));
    const docs = refs.length ? await db().getAll(...refs) : [];
    const profileByUid = {};
    docs.forEach((d) => {
      if (d.exists) profileByUid[d.id] = d.data();
    });

    const userList = farmers.map((u) => ({
      uid: u.uid,
      email_address: u.email,
      ...(profileByUid[u.uid] || {}),
    }));

    return {users: userList};
  } catch (error) {
    logger.error("listUsers failed", {code: error.code});
    throw new HttpsError("internal", "Failed to list users.");
  }
});

exports.updateUser = onCall(async (request) => {
  requireAdmin(request);

  const {
    uid, firstName, lastName, emailAddress, contactNumber, address, password,
  } = request.data || {};
  if (!uid || !emailAddress || !firstName || !lastName) {
    throw new HttpsError(
      "invalid-argument",
      "Missing required fields: uid, emailAddress, firstName, lastName."
    );
  }

  try {
    const authUpdate = {email: emailAddress};
    if (password) authUpdate.password = password;
    await auth().updateUser(uid, authUpdate);

    await db().collection("users").doc(uid).update({
      first_name: firstName,
      last_name: lastName,
      contact_number: contactNumber || "",
      address: address || "",
      uid,
    });

    return {
      userRecord: {
        email_address: emailAddress,
        first_name: firstName,
        last_name: lastName,
        contact_number: contactNumber,
        address,
      },
    };
  } catch (error) {
    logger.error("updateUser failed", {code: error.code});
    throw new HttpsError("internal", "Failed to update user.");
  }
});

exports.deleteUser = onCall(async (request) => {
  requireAdmin(request);

  const {uid} = request.data || {};
  if (!uid) {
    throw new HttpsError("invalid-argument", "Missing uid.");
  }

  try {
    await auth().deleteUser(uid);

    // Remove the profile and cascade-delete the user's owned data so we
    // don't leave orphaned farms/assessments/enrollments behind.
    await db().collection("users").doc(uid).delete();

    const farms = await db()
      .collection("farms")
      .where("ownerUid", "==", uid)
      .get();
    for (const farm of farms.docs) {
      await db().recursiveDelete(farm.ref); // farm + its subcollections
    }

    await deleteByQuery(
      db().collection("assessments").where("farmer_id", "==", uid)
    );
    await deleteByQuery(
      db().collection("enrollments").where("farmerId", "==", uid)
    );

    return {success: true, message: `User ${uid} deleted.`};
  } catch (error) {
    logger.error("deleteUser failed", {code: error.code});
    throw new HttpsError("internal", "Failed to delete user.");
  }
});

// ---------------------------------------------------------------------------
// Farms
// ---------------------------------------------------------------------------

exports.createFarm = onCall(async (request) => {
  requireAdmin(request);

  const {uid, name, areaHa, address} = request.data || {};
  if (!uid || !name) {
    throw new HttpsError("invalid-argument", "Missing uid or name.");
  }

  try {
    const ref = await db().collection("farms").add({
      ownerUid: uid,
      name,
      areaHa: areaHa ?? null,
      address: address || "",
      createdAt: FieldValue.serverTimestamp(),
      planting: {year: null},
      diseasePest: {anthracnose: false, powderyMildew: false},
    });
    return {success: true, farmId: ref.id};
  } catch (error) {
    logger.error("createFarm failed", {code: error.code});
    throw new HttpsError("internal", "Failed to create farm.");
  }
});

exports.updateFarm = onCall(async (request) => {
  requireAdmin(request);

  const {farmId, name, areaHa, address} = request.data || {};
  if (!farmId) {
    throw new HttpsError("invalid-argument", "Missing farmId.");
  }

  // Only write fields the caller actually provided. The Admin SDK throws on
  // `undefined` values, so an omitted field must be left out of the update
  // rather than passed through as undefined.
  const updates = {};
  if (name !== undefined) updates.name = name;
  if (address !== undefined) updates.address = address;
  if (areaHa !== undefined) updates.areaHa = areaHa;

  if (Object.keys(updates).length === 0) {
    throw new HttpsError("invalid-argument", "No fields to update.");
  }

  try {
    await db().collection("farms").doc(farmId).update(updates);
    return {success: true, farmId};
  } catch (error) {
    logger.error("updateFarm failed", {code: error.code});
    throw new HttpsError("internal", "Failed to update farm.");
  }
});

exports.deleteFarm = onCall(async (request) => {
  requireAdmin(request);

  const {farmId} = request.data || {};
  if (!farmId) {
    throw new HttpsError("invalid-argument", "Missing farmId.");
  }

  try {
    // recursiveDelete also removes yields/irrigations/observations.
    await db().recursiveDelete(db().collection("farms").doc(farmId));
    return {success: true, farmId};
  } catch (error) {
    logger.error("deleteFarm failed", {code: error.code});
    throw new HttpsError("internal", "Failed to delete farm.");
  }
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Deletes every document matched by a query, in batches of 400. */
async function deleteByQuery(query) {
  const snap = await query.get();
  for (let i = 0; i < snap.docs.length; i += 400) {
    const batch = db().batch();
    snap.docs.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}
