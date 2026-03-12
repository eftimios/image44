# Unique task identifier
TASK_ID="052e12fc-92b2-48c6-a5c9-299aa9480e1a"

# Base model to fine-tune (from HuggingFace)
MODEL="zenless-lab/sdxl-anima-pencil-xl-v5"

# Dataset ZIP file location (must be a ZIP file with images)
DATASET_ZIP="https://huggingface.co/datasets/harry1203/training-data/resolve/main/tourn_4e1b54957c766afb_20260226/052e12fc-92b2-48c6-a5c9-299aa9480e1a/training_data.zip"

# Model type: "sdxl" or "flux"
MODEL_TYPE="sdxl"

# Optional: Repository name for the trained model
EXPECTED_REPO_NAME="test-sdxl-anima-pencil-xl-v5-4"

# For uploading the outputs
HUGGINGFACE_TOKEN=""
HUGGINGFACE_USERNAME=""
LOCAL_FOLDER="/app/checkpoints/$TASK_ID/$EXPECTED_REPO_NAME"

CHECKPOINTS_DIR="$(pwd)/secure_checkpoints"
OUTPUTS_DIR="$(pwd)/outputs"
mkdir -p "$CHECKPOINTS_DIR"
chmod 700 "$CHECKPOINTS_DIR"
mkdir -p "$OUTPUTS_DIR"
chmod 700 "$OUTPUTS_DIR"

# Build the downloader image
docker build --no-cache -t trainer-downloader -f dockerfiles/trainer-downloader.dockerfile .

# Build the trainer image
docker build --no-cache -t standalone-image-trainer -f dockerfiles/standalone-image-trainer.dockerfile .

# Build the hf uploader image
docker build --no-cache -t hf-uploader -f dockerfiles/hf-uploader.dockerfile .

# Download model and dataset
echo "Downloading model and dataset..."
docker run --rm \
  --volume "$CHECKPOINTS_DIR:/cache:rw" \
  --name downloader-image \
  trainer-downloader \
  --task-id "$TASK_ID" \
  --model "$MODEL" \
  --dataset "$DATASET_ZIP" \
  --task-type "ImageTask"

# Run the training
echo "Starting image training..."
docker run --rm --gpus all \
  --security-opt=no-new-privileges \
  --cap-drop=ALL \
  --memory=36g \
  --cpus=8 \
  --network none \
  --env TRANSFORMERS_CACHE=/cache/hf_cache \
  --volume "$CHECKPOINTS_DIR:/cache:rw" \
  --volume "$OUTPUTS_DIR:/app/checkpoints/:rw" \
  --name image-trainer-example \
  standalone-image-trainer \
  --task-id "$TASK_ID" \
  --model "$MODEL" \
  --dataset-zip "$DATASET_ZIP" \
  --model-type "$MODEL_TYPE" \
  --expected-repo-name "$EXPECTED_REPO_NAME" \
  --hours-to-complete 1

echo "Uploading model to HuggingFace..."
docker run --rm --gpus all \
  --volume "$OUTPUTS_DIR:/app/checkpoints/:rw" \
  --env HUGGINGFACE_TOKEN="$HUGGINGFACE_TOKEN" \
  --env HUGGINGFACE_USERNAME="$HUGGINGFACE_USERNAME" \
  --env TASK_ID="$TASK_ID" \
  --env EXPECTED_REPO_NAME="$EXPECTED_REPO_NAME" \
  --env LOCAL_FOLDER="$LOCAL_FOLDER" \
  --env HF_REPO_SUBFOLDER="checkpoints" \
  --name hf-uploader \
  hf-uploader