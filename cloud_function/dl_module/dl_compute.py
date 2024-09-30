import os
import re
import torch
import cv2
import numpy as np
import pandas as pd
from PIL import Image
from flask import Flask, request, jsonify
from firebase_admin import credentials, firestore, initialize_app
from transformers import AutoImageProcessor, SegformerForSemanticSegmentation

# Firebase initialization
cred = credentials.Certificate('credentials.json')
initialize_app(cred)
db = firestore.client()

# Load Segformer model
segformer_processor = AutoImageProcessor.from_pretrained("nvidia/segformer-b0-finetuned-ade-512-512", do_reduce_labels=True)
segformer_model = SegformerForSemanticSegmentation.from_pretrained("nvidia/segformer-b0-finetuned-ade-512-512").to('cpu')

# Load Yolov5 model
yolo_model = torch.hub.load('ultralytics/yolov5', 'yolov5s', pretrained=True)

app = Flask(__name__)

# Function to process a single image with Segformer
def process_image_with_segformer(image_path):
    image = Image.open(image_path).convert("RGB")
    original_size = image.size
    inputs = segformer_processor(images=image, return_tensors="pt")
    inputs = {k: v.to('cpu') for k, v in inputs.items()}

    with torch.no_grad():
        outputs = segformer_model(**inputs)
        logits = outputs.logits

    segmentation = torch.argmax(logits, dim=1)[0]
    segmentation = torch.nn.functional.interpolate(
        segmentation.unsqueeze(0).unsqueeze(0).float(),
        size=(original_size[1], original_size[0]),
        mode='nearest'
    ).squeeze().long()

    class_coding = pd.read_csv('./ADE20K_Class_Coding.csv')
    sky_class = class_coding[class_coding['Name'] == 'sky']['Idx'].values[0] - 1
    tree_class = class_coding[class_coding['Name'] == 'tree']['Idx'].values[0] - 1

    total_pixels = segmentation.numel()
    sky_pixels = int((segmentation == sky_class).sum().item())
    tree_pixels = int((segmentation == tree_class).sum().item())

    sky_proportion = sky_pixels / total_pixels
    tree_proportion = tree_pixels / total_pixels

    return sky_proportion, tree_proportion

# Function to process a single image with Yolov5
def process_image_with_yolov5(image_path):
    image = cv2.imread(image_path)
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = yolo_model(image_rgb)

    labels = results.xyxyn[0][:, -1].cpu().numpy()
    person_class_index = 0
    motor_vehicle_class_indices = [2, 3, 5, 7]
    non_motor_vehicle_class_indices = [1]

    person_count = int(sum(labels == person_class_index))
    motor_vehicle_count = int(sum(np.isin(labels, motor_vehicle_class_indices)))
    non_motor_vehicle_count = int(sum(np.isin(labels, non_motor_vehicle_class_indices)))

    return person_count, motor_vehicle_count, non_motor_vehicle_count

def process_images_for_record(user_id, record_id, image_path):
    image_files = [f for f in os.listdir(image_path) if f.startswith(record_id) and f.endswith('.jpg')]
    image_paths = [os.path.join(image_path, f) for f in image_files]
    timestamps = [re.search(r'_(.*)\.jpg', f).group(1) for f in image_files]

    # Get the existing document
    doc_ref = db.collection('data').document(user_id).collection('records').document(record_id)
    doc = doc_ref.get()

    if doc.exists:
        data = doc.to_dict()
        sensor_data_list = data.get('sensorData', [])
        
        # Process each image separately and update the data
        for i, image_path in enumerate(image_paths):
            timestamp = timestamps[i]
            sky_proportion, tree_proportion = process_image_with_segformer(image_path)
            person_count, motor_vehicle_count, non_motor_vehicle_count = process_image_with_yolov5(image_path)
            
            for entry in sensor_data_list:
                if entry.get('time') == timestamp:
                    entry['dlData'] = {
                        'pc': person_count,
                        'mvc': motor_vehicle_count,
                        'nmvc': non_motor_vehicle_count,
                        'sp': sky_proportion,
                        'tp': tree_proportion
                    }
                    break

        # Save the updated document
        doc_ref.set({'sensorData': sensor_data_list}, merge=True)
        print(f"Processed and saved data for {record_id}")

@app.route('/process_images', methods=['POST'])
def process_images():
    data = request.json
    user_id = data.get('userId')
    record_id = data.get('recordId')

    if not user_id or not record_id:
        return jsonify({'error': 'userId and recordId are required'}), 400

    image_path = '/home/ubuntu/Dissertation_Application/cloud_function/websocket_server/images'
    process_images_for_record(user_id, record_id, image_path)
    
    return jsonify({'message': f'Processed images for recordId: {record_id} and userId: {user_id}'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002)
