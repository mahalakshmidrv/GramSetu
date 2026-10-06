// Offline reference content, bundled with the app shell so it works with no internet.
// General awareness only - not medical or agronomic prescriptions.
const L = (en, hi, ta) => ({ en, hi, ta });
const HEALTH_INFO = [
 { icon:"💧", title:L("Loose motions and safe water","दस्त और साफ पानी","வயிற்றுப்போக்கு மற்றும் பாதுகாப்பான நீர்"),
   body:L("Drink plenty of boiled or filtered water. ORS (oral rehydration solution) replaces lost fluids; ask your ASHA worker or health centre. See a health worker if it lasts more than a day or two, there is blood, or a child or elderly person is very weak.",
          "उबला या छाना हुआ पानी खूब पिएं। ORS शरीर में पानी की कमी पूरी करता है; आशा कार्यकर्ता या स्वास्थ्य केंद्र से पूछें। अगर एक-दो दिन से ज्यादा रहे, खून आए, या बच्चा/बुजुर्ग बहुत कमजोर हो तो स्वास्थ्य कार्यकर्ता को दिखाएं।",
          "கொதிக்க வைத்த அல்லது வடிகட்டிய நீரை நிறைய குடியுங்கள். ORS இழந்த நீரை ஈடுசெய்யும்; ஆஷா பணியாளர் அல்லது சுகாதார மையத்தில் கேளுங்கள். ஓரிரு நாளுக்கு மேல் நீடித்தால், இரத்தம் வந்தால், குழந்தை/முதியவர் மிகவும் சோர்வாக இருந்தால் சுகாதாரப் பணியாளரைப் பாருங்கள்.") },
 { icon:"🦟", title:L("Fever and mosquitoes","बुखार और मच्छर","காய்ச்சல் மற்றும் கொசுக்கள்"),
   body:L("Do not let water stand in pots, tyres or coolers where mosquitoes breed. Use mosquito nets. If fever lasts more than 2 days, or comes with rash, severe headache or vomiting, get tested at a government health centre.",
          "मटकों, टायरों या कूलर में पानी जमा न होने दें, वहां मच्छर पनपते हैं। मच्छरदानी लगाएं। बुखार 2 दिन से ज्यादा रहे, या दाने, तेज सिरदर्द या उल्टी हो तो सरकारी स्वास्थ्य केंद्र में जांच कराएं।",
          "கொசு வளரும் பானைகள், டயர்கள், கூலர்களில் நீர் தேங்க விடாதீர்கள். கொசு வலை பயன்படுத்துங்கள். காய்ச்சல் 2 நாளுக்கு மேல் நீடித்தால், அல்லது தடிப்பு, கடும் தலைவலி, வாந்தி இருந்தால் அரசு சுகாதார மையத்தில் பரிசோதியுங்கள்.") },
 { icon:"🤱", title:L("Mothers and babies","माँ और शिशु","தாய் மற்றும் குழந்தை"),
   body:L("Pregnant women should register at the nearest Anganwadi or health centre and attend regular check-ups. Keep the baby's vaccination card safe and follow the vaccine dates given by the health worker.",
          "गर्भवती महिलाएं नजदीकी आंगनवाड़ी या स्वास्थ्य केंद्र में पंजीकरण कराएं और नियमित जांच करवाएं। शिशु का टीकाकरण कार्ड संभालकर रखें और स्वास्थ्य कार्यकर्ता की बताई तारीखों पर टीके लगवाएं।",
          "கர்ப்பிணிகள் அருகிலுள்ள அங்கன்வாடி அல்லது சுகாதார மையத்தில் பதிவு செய்து, தவறாமல் பரிசோதனை செய்யுங்கள். குழந்தையின் தடுப்பூசி அட்டையை பத்திரமாக வைத்து, சுகாதாரப் பணியாளர் கூறும் தேதிகளில் தடுப்பூசி போடுங்கள்.") },
 { icon:"😷", title:L("Cough that does not go away","ठीक न होने वाली खांसी","குணமாகாத இருமல்"),
   body:L("A cough lasting more than 2 weeks, especially with fever or weight loss, should be checked for TB. TB tests and treatment are available free at government health facilities.",
          "2 हफ्ते से ज्यादा खांसी, खासकर बुखार या वजन घटने के साथ, हो तो टीबी की जांच कराएं। सरकारी स्वास्थ्य केंद्रों में टीबी की जांच और इलाज मुफ्त है।",
          "2 வாரத்துக்கு மேல் இருமல், குறிப்பாக காய்ச்சல் அல்லது எடை குறைவுடன் இருந்தால், காசநோய் பரிசோதனை செய்யுங்கள். அரசு சுகாதார நிலையங்களில் காசநோய் பரிசோதனையும் சிகிச்சையும் இலவசம்.") },
 { icon:"🧼", title:L("Hygiene and food","स्वच्छता और भोजन","சுகாதாரம் மற்றும் உணவு"),
   body:L("Wash hands with soap before cooking and eating and after using the toilet. Cover food, and drink safe water.",
          "खाना बनाने और खाने से पहले तथा शौच के बाद साबुन से हाथ धोएं। खाना ढककर रखें और साफ पानी पिएं।",
          "சமைப்பதற்கும் சாப்பிடுவதற்கும் முன்பும், கழிப்பறைக்குப் பின்பும் சோப்பால் கை கழுவுங்கள். உணவை மூடி வையுங்கள்; பாதுகாப்பான நீரைக் குடியுங்கள்.") }
];
const HELPLINES = [
 { num:"112", name:L("All emergencies","सभी आपातकाल","அனைத்து அவசரநிலைகள்") },
 { num:"108", name:L("Ambulance","एम्बुलेंस","ஆம்புலன்ஸ்") },
 { num:"102", name:L("Ambulance for mothers and babies (many states)","माँ-शिशु एम्बुलेंस (कई राज्यों में)","தாய்-சேய் ஆம்புலன்ஸ் (பல மாநிலங்களில்)") },
 { num:"14555", name:L("Ayushman Bharat helpline","आयुष्मान भारत हेल्पलाइन","ஆயுஷ்மான் பாரத் உதவி எண்") },
 { num:"1098", name:L("Childline","चाइल्डलाइन","சைல்டுலைன்") },
 { num:"181", name:L("Women helpline","महिला हेल्पलाइन","பெண்கள் உதவி எண்") },
 { num:"14567", name:L("Senior citizen helpline","वरिष्ठ नागरिक हेल्पलाइन","முதியோர் உதவி எண்") }
];
const FARM_HELPLINES = [
 { num:"1800-180-1551", name:L("Kisan Call Centre","किसान कॉल सेंटर","கிசான் அழைப்பு மையம்") },
 { num:"155261", name:L("PM-KISAN helpline","पीएम-किसान हेल्पलाइन","பிஎம்-கிசான் உதவி எண்") }
];
const CROPS = [
 { icon:"🌧️", title:L("Kharif (monsoon) crops","खरीफ (बरसात) फसलें","கரீஃப் (பருவமழை) பயிர்கள்"),
   body:L("Sown with the monsoon (about June–July), harvested about September–October. Examples: rice, maize, millets (jowar, bajra, ragi), cotton, groundnut, soybean, tur, moong, urad.",
          "मानसून के साथ बोई जाती हैं (लगभग जून–जुलाई), कटाई लगभग सितंबर–अक्टूबर। उदाहरण: धान, मक्का, मोटे अनाज (ज्वार, बाजरा, रागी), कपास, मूंगफली, सोयाबीन, अरहर, मूंग, उड़द।",
          "பருவமழையுடன் விதைக்கப்படும் (சுமார் ஜூன்–ஜூலை), அறுவடை சுமார் செப்டம்பர்–அக்டோபர். எ.கா: நெல், மக்காச்சோளம், சிறுதானியங்கள் (சோளம், கம்பு, ராகி), பருத்தி, நிலக்கடலை, சோயா, துவரை, பாசிப்பயறு, உளுந்து.") },
 { icon:"❄️", title:L("Rabi (winter) crops","रबी (सर्दी) फसलें","ராபி (குளிர்கால) பயிர்கள்"),
   body:L("Sown about October–December, harvested about March–April. Examples: wheat, barley, mustard, gram (chana), peas.",
          "लगभग अक्टूबर–दिसंबर में बोई जाती हैं, कटाई लगभग मार्च–अप्रैल। उदाहरण: गेहूं, जौ, सरसों, चना, मटर।",
          "சுமார் அக்டோபர்–டிசம்பரில் விதைக்கப்படும், அறுவடை சுமார் மார்ச்–ஏப்ரல். எ.கா: கோதுமை, பார்லி, கடுகு, கொண்டைக்கடலை, பட்டாணி.") },
 { icon:"☀️", title:L("Zaid (summer) crops","जायद (गर्मी) फसलें","சைத் (கோடை) பயிர்கள்"),
   body:L("Short-season crops grown about March–June with irrigation: watermelon, cucumber, vegetables, fodder.",
          "लगभग मार्च–जून में सिंचाई से उगाई जाने वाली कम अवधि की फसलें: तरबूज, खीरा, सब्जियां, चारा।",
          "சுமார் மார்ச்–ஜூனில் நீர்ப்பாசனத்துடன் விளையும் குறுகிய காலப் பயிர்கள்: தர்பூசணி, வெள்ளரி, காய்கறிகள், தீவனம்.") },
 { icon:"📌", title:L("Note","ध्यान दें","குறிப்பு"),
   body:L("Exact timing and varieties differ by region. Ask your Krishi Vigyan Kendra (KVK) or agriculture office for your area.",
          "सही समय और किस्में क्षेत्र के अनुसार बदलती हैं। अपने क्षेत्र के लिए कृषि विज्ञान केंद्र (KVK) या कृषि कार्यालय से पूछें।",
          "சரியான காலமும் ரகங்களும் பகுதிக்கு ஏற்ப மாறும். உங்கள் பகுதிக்கு வேளாண் அறிவியல் நிலையம் (KVK) அல்லது வேளாண் அலுவலகத்தில் கேளுங்கள்.") }
];
const FARM_GUIDE = [
 { icon:"🌱", title:L("Seeds","बीज","விதைகள்"),
   body:L("Buy certified, labelled seed from government agencies or authorised dealers. Keep the bill and the seed tag. Use seed that suits your season and soil.",
          "सरकारी एजेंसी या अधिकृत विक्रेता से प्रमाणित, लेबल वाला बीज खरीदें। बिल और बीज का टैग संभालकर रखें। अपने मौसम और मिट्टी के अनुसार बीज चुनें।",
          "அரசு நிறுவனங்கள் அல்லது அங்கீகரிக்கப்பட்ட விற்பனையாளரிடம் சான்றளிக்கப்பட்ட, லேபிள் உள்ள விதையை வாங்குங்கள். பில்லையும் விதை அட்டையையும் வைத்திருங்கள். உங்கள் பருவம், மண்ணுக்கு ஏற்ற விதையைத் தேர்வு செய்யுங்கள்.") },
 { icon:"🧪", title:L("Fertilizer","खाद","உரம்"),
   body:L("Test your soil (see Soil Health Card) and use the recommended amount. Add compost or farmyard manure. Too much urea harms soil and wastes money. Read the label.",
          "मिट्टी की जांच कराएं (मृदा स्वास्थ्य कार्ड देखें) और सुझाई मात्रा में ही खाद डालें। कम्पोस्ट या गोबर की खाद मिलाएं। ज्यादा यूरिया मिट्टी को नुकसान और पैसे की बर्बादी है। लेबल पढ़ें।",
          "மண்ணைப் பரிசோதியுங்கள் (மண் வள அட்டை பார்க்கவும்); பரிந்துரைக்கப்பட்ட அளவே இடுங்கள். கம்போஸ்ட் அல்லது தொழுவுரம் சேருங்கள். அதிக யூரியா மண்ணைக் கெடுக்கும், பணமும் வீண். லேபிளைப் படியுங்கள்.") },
 { icon:"💦", title:L("Water","पानी","நீர்"),
   body:L("Avoid over-watering. Drip or sprinkler irrigation can save water. Water early morning or evening.",
          "जरूरत से ज्यादा सिंचाई न करें। ड्रिप या स्प्रिंकलर से पानी बचता है। सुबह जल्दी या शाम को सिंचाई करें।",
          "அதிகமாக நீர் பாய்ச்சாதீர்கள். சொட்டு அல்லது தெளிப்பு நீர்ப்பாசனம் நீரைச் சேமிக்கும். அதிகாலை அல்லது மாலையில் பாய்ச்சுங்கள்.") },
 { icon:"🐛", title:L("Pests and sprays","कीट और छिड़काव","பூச்சிகளும் தெளிப்பும்"),
   body:L("Check your field regularly. Ask KVK or the agriculture office before spraying. Follow the label dose, cover your face and hands, and keep chemicals away from children and food.",
          "खेत की नियमित निगरानी करें। छिड़काव से पहले KVK या कृषि कार्यालय से पूछें। लेबल की मात्रा मानें, चेहरा-हाथ ढकें, रसायन बच्चों और खाने से दूर रखें।",
          "வயலை அடிக்கடி கண்காணியுங்கள். தெளிக்கும் முன் KVK அல்லது வேளாண் அலுவலகத்தில் கேளுங்கள். லேபிள் அளவைப் பின்பற்றி, முகம் கைகளை மூடிக்கொள்ளுங்கள்; ரசாயனங்களை குழந்தைகள், உணவிலிருந்து தூரமாக வைக்கவும்.") },
 { icon:"🔄", title:L("Crop rotation","फसल चक्र","பயிர் சுழற்சி"),
   body:L("Growing pulses in rotation with cereals helps restore soil fertility.",
          "अनाज के साथ बारी-बारी से दलहन उगाने से मिट्टी की उर्वरता लौटती है।",
          "தானியங்களுடன் மாறி மாறி பருப்பு வகைகளை பயிரிடுவது மண் வளத்தை மீட்கும்.") }
];
