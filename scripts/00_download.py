import os
import kagglehub

path = kagglehub.dataset_download("maharshipandya/-spotify-tracks-dataset")
print("Path to dataset files:", path)
print("Arquivos:", os.listdir(path))
