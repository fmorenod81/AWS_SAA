
#Crear una carpeta para ser usado como punto de montaje
sudo mkdir /data
#Este comando comprueba que fue "attachado" a la instancia. Se verifica por tamaño la ruta del dispositivo.
lsblk
#Este comando crea el filesystem al dispositivo
##### COMMAND TO CREATE FILESYSTEM #########
sudo mkfs -t xfs /dev/nvme1n1
#############################################
# Este comando monta el dispositivo fisico a una carpeta de su instancia
sudo mount -o rw /dev/nvme1n1 /data
sudo chown ec2-user:ec2-user /data
ls -la /data
#Aqui ya se pueden crear archivos
echo "This a shared file using Multiattach EBS" >/data/Labs.txt
cat /data/Labs.txt

#Comandos Importantes
cd /
sudo umount /dev/nvme1n1

dmesg | tail
sudo xfs_repair -n /dev/nvme1n1 -v
sudo xfs_repair -L /dev/nvme1n1 -v


# Para hacer el resize
lsblk
sudo mkfs -t xfs /dev/nvme2n1
sudo mkdir /data2
sudo mount -o rw /dev/nvme2n1 /data2
sudo chown ec2-user:ec2-user /data2
ls -la /data2
echo "Cualquier cosa para resizing" >/data2/Labs.txt
cat /data2/Labs.txt

df -hT
sudo xfs_growfs -d /data2
df -hT
