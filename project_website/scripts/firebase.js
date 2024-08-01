import { initializeApp } from "https://www.gstatic.com/firebasejs/9.0.0/firebase-app.js";
import { getFirestore, collection, getDocs } from "https://www.gstatic.com/firebasejs/9.0.0/firebase-firestore.js";
import config from "./config.js";

const firebaseConfig = {
  apiKey: config.FIREBASE_API_KEY,
  authDomain: "geoscanner-e6eff.firebaseapp.com",
  projectId: "geoscanner-e6eff",
  storageBucket: "geoscanner-e6eff.appspot.com",
  messagingSenderId: "91500286107",
  appId: "1:91500286107:web:c629bf72ef76d05fe8b63e",
  measurementId: "G-ZXNRCRMDSD",
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

export { db, collection, getDocs };
