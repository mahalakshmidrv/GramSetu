import streamlit as st

st.set_page_config(
    page_title="GramSetu",
    page_icon="🌾",
    layout="wide"
)

st.title("🌾 GramSetu")
st.subheader("The Village Bridge")

st.write(
    "An offline-first platform connecting rural communities "
    "with government services, healthcare, agriculture, "
    "document support, and emergency assistance."
)

st.divider()

menu = st.sidebar.selectbox(
    "Select Service",
    [
        "Dashboard",
        "Government Services",
        "Healthcare",
        "Farmer Support",
        "Document Services",
        "SOS Support",
        "Offline Assistant"
    ]
)

if menu == "Dashboard":
    st.header("🏠 Dashboard")

    col1, col2, col3 = st.columns(3)

    with col1:
        st.metric("Government Services", "5")

    with col2:
        st.metric("Healthcare", "Available")

    with col3:
        st.metric("Offline Support", "Enabled")

elif menu == "Government Services":
    st.header("🏛️ Government Services")

    services = [
        "PM-KISAN",
        "Ayushman Bharat",
        "MGNREGA",
        "Jal Jeevan Mission",
        "NSAP Pension"
    ]

    for service in services:
        st.info(service)

elif menu == "Healthcare":
    st.header("🏥 Healthcare Support")
    st.write("Access healthcare information and emergency guidance.")
    st.warning("For serious emergencies, contact local emergency services.")

elif menu == "Farmer Support":
    st.header("🌾 Farmer Support")
    st.write("Access agricultural information and farmer support services.")

elif menu == "Document Services":
    st.header("📄 Document Services")

    uploaded_file = st.file_uploader(
        "Upload a document",
        type=["pdf", "jpg", "jpeg", "png"]
    )

    if uploaded_file:
        st.success(f"{uploaded_file.name} uploaded successfully.")

elif menu == "SOS Support":
    st.header("🚨 SOS Support")

    if st.button("Create SOS Request"):
        st.warning("SOS request created for synchronization.")

elif menu == "Offline Assistant":
    st.header("🤖 GramSetu Assistant")

    question = st.text_input("Ask your question")

    if question:
        st.info(
            "Please check the relevant GramSetu service "
            "for detailed information."
        )

st.divider()

st.caption(
    "GramSetu — Bridging rural communities to government services, "
    "healthcare, information, and opportunity."
)