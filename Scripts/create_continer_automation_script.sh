echo "Process Inilize the Continer creation"

mkdir tom
cd tom

cat << 'EOF'> Dockerfile

FROM debian:stable-slim
RUN apt-get update && apt-get install -y curl

CMD ["echo","TOM Docke Continer created Successfully"]

EOF

echo "Continer Creation Sucessfully"

echo "Continer verification"

ls -la

echo "continer Building..."

docker build -t tom .

echo "Docker Continer Running Process...."

docker run tom
