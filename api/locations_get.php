<?php
// api/locations_get.php
// Master dataset of Tamil Nadu 38 Districts & Indian States for match/tournament filtering.
// GET /api/locations_get.php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

$tnDistricts = [
    'Coimbatore',
    'Chennai',
    'Madurai',
    'Salem',
    'Tiruppur',
    'Erode',
    'Tiruchirappalli (Trichy)',
    'Tirunelveli',
    'Vellore',
    'Thanjavur',
    'Dindigul',
    'Kanyakumari (Nagercoil)',
    'Namakkal',
    'Nilgiris (Ooty)',
    'Karur',
    'Dharmapuri',
    'Krishnagiri',
    'Cuddalore',
    'Villupuram',
    'Kanchipuram',
    'Chengalpattu',
    'Thiruvallur',
    'Ranipet',
    'Tirupathur',
    'Tiruvannamalai',
    'Kallakurichi',
    'Nagapattinam',
    'Mayiladuthurai',
    'Tiruvarur',
    'Pudukkottai',
    'Sivagangai',
    'Ramanathapuram',
    'Virudhunagar',
    'Theni',
    'Tenkasi',
    'Thoothukudi (Tuticorin)',
    'Ariyalur',
    'Perambalur'
];

$states = [
    [
        'state' => 'Tamil Nadu',
        'is_default' => true,
        'districts' => $tnDistricts
    ],
    [
        'state' => 'Kerala',
        'districts' => ['Palakkad', 'Ernakulam (Kochi)', 'Thiruvananthapuram', 'Kozhikode', 'Thrissur', 'Kollam', 'Kannur', 'Kottayam', 'Malappuram', 'Alappuzha', 'Idukki', 'Pathanamthitta', 'Wayanad', 'Kasaragod']
    ],
    [
        'state' => 'Karnataka',
        'districts' => ['Bengaluru Urban', 'Bengaluru Rural', 'Mysuru', 'Mangaluru', 'Hubballi-Dharwad', 'Belagavi', 'Tumakuru', 'Shivamogga', 'Ballari', 'Udupi']
    ],
    [
        'state' => 'Andhra Pradesh',
        'districts' => ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Tirupati', 'Kurnool', 'Nellore', 'Kakinada', 'Anantapur', 'Kadapa']
    ],
    [
        'state' => 'Telangana',
        'districts' => ['Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar', 'Khammam']
    ],
    [
        'state' => 'Puducherry',
        'districts' => ['Puducherry', 'Karaikal', 'Mahe', 'Yanam']
    ],
    [
        'state' => 'Maharashtra',
        'districts' => ['Mumbai City', 'Mumbai Suburban', 'Pune', 'Nagpur', 'Thane', 'Nashik', 'Aurangabad (Chhatrapati Sambhajinagar)', 'Solapur', 'Kolhapur']
    ],
    [
        'state' => 'Delhi NCR',
        'districts' => ['New Delhi', 'North Delhi', 'South Delhi', 'Noida (Gautam Buddha Nagar)', 'Gurugram', 'Faridabad', 'Ghaziabad']
    ]
];

echo json_encode([
    'success' => true,
    'default_state' => 'Tamil Nadu',
    'default_district' => 'Coimbatore',
    'tamil_nadu_districts' => $tnDistricts,
    'states' => $states
]);
