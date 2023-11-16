from roboflow import Roboflow
import os
import subprocess
import torch


print(torch.cuda.is_available())
print(torch.cuda.current_device())
print(torch.cuda.device_count())
print(torch.cuda.get_device_name(0))


from roboflow import Roboflow
rf = Roboflow(api_key="IeS4K49I1zr0cAobg9Py")
project = rf.workspace("esp3201-project").project("fine-tune-1")
dataset = project.version(1).download("yolov7")
#os.chdir(new_path)

subprocess.run(['curl', '-O', 'https://github.com/shuhuiii/esp3201_meso/blob/main/best_trained.pt'])

subprocess.run(['python', 'train.py', '--batch', '16', '--epochs', '10', '--data', f"{dataset.location}/data.yaml", '--weights', 'best_trained.pt', '--device', '0'])

subprocess.run(['python', 'detect.py', '--weights', 'best_FT2_Changed_LR.pt', '--conf', '0.1', '--source', 'Project/Random Test/Jpeg'])

#display inference on ALL test images

import glob
from IPython.display import Image, display

i = 0
limit = 10000 # max images to print
for imageName in glob.glob('/content/yolov7/runs/detect/exp/*.jpg'): #assuming JPG
    if i < limit:
      display(Image(filename=imageName))
      print("\n")
    i = i + 1

# optional, zip to download weights and results locally

#!zip -r export.zip runs/detect
#!zip -r export.zip runs/train/exp/weights/best.pt
#!zip export.zip runs/train/exp/*

# # setup access to your workspace
# rf = Roboflow(api_key="YOUR_API_KEY")                               # used above to load data
# inference_project =  rf.workspace().project("YOUR_PROJECT_NAME")    # used above to load data
# model = inference_project.version(1).model

# upload_project = rf.workspace().project("YOUR_PROJECT_NAME")

# print("inference reference point: ", inference_project)
# print("upload destination: ", upload_project)

# # example upload: if prediction is below a given confidence threshold, upload it

# confidence_interval = [10,70]                                   # [lower_bound_percent, upper_bound_percent]

# for prediction in predictions:                                  # predictions list to loop through
#   if(prediction['confidence'] * 100 >= confidence_interval[0] and
#           prediction['confidence'] * 100 <= confidence_interval[1]):

#           # upload on success!
#           print(' >> image uploaded!')
#           upload_project.upload(image, num_retry_uploads=3)     # upload image in question

#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