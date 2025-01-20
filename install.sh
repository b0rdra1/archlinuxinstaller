#!/bin/bash

# Проверка на root
if [ "$(id -u)" -ne 0 ]; then
  echo "Этот скрипт нужно запускать с правами root!"
  exit 1
fi

# Запуск fdisk для создания разделов
echo -e "o\nn\np\n1\n\n+512M\nt\n1\nn\np\n2\n\n+${SWAP_SIZE}M\nt\n2\n82\nn\np\n3\n\n\nw" | fdisk /dev/sdb

# Обновляем таблицу разделов
partprobe /dev/sdb

# Форматируем разделы
mkfs.fat -F32 /dev/sdb1        # Форматируем раздел EFI
mkswap /dev/sdb2               # Форматируем раздел под swap
swapon /dev/sdb2               # Включаем swap
mkfs.ext4 /dev/sdb3            # Форматируем раздел Linux Filesystem

# Создание точек монтирования
mkdir -p /mnt/boot/efi
mkdir -p /mnt

# Монтируем разделы
mount /dev/sdb3 /mnt            # Монтируем основной раздел
mount /dev/sdb1 /mnt/boot/efi   # Монтируем раздел EFI


# Установка базовых пакетов
echo "Устанавливаем базовую систему..."
pacstrap -K /mnt base linux linux-firmware sudo nano

# Настройка fstab
echo "Настроим fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Монтируем /dev и /proc для chroot
echo "Монтируем /dev и /proc для chroot..."
mount --types proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev
mount --rbind /dev/pts /mnt/dev/pts

# Переходим в chroot
echo "Заходим в chroot..."
arch-chroot /mnt

# Настройка часового пояса
echo "Настроим часовой пояс..."
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime

# Настройка локалей
echo "Настроим локали..."
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/#ru_RU.UTF-8/ru_RU.UTF-8/' /etc/locale.gen
locale-gen

# Синхронизация аппаратных часов
echo "Синхронизируем аппаратные часы..."
hwclock --systohc

# Установка локали
echo "Устанавливаем локаль..."
echo LANG=ru_RU.UTF-8 > /etc/locale.conf
export LANG=ru_RU.UTF-8

# Установка имени хоста
echo "Устанавливаем имя хоста..."
echo arch-pc > /etc/hostname

# Настройка файла hosts
echo "Настроим файл /etc/hosts..."
cat <<EOF > /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    arch-pc.localdomain arch-pc
EOF

# Установка пароля для пользователя root
echo "Устанавливаем пароль для root..."
passwd

# Установка загрузчика и утилит
echo "Устанавливаем загрузчик и утилиты..."
pacman -S --noconfirm grub efibootmgr os-prober mtools

# Монтируем EFI раздел
echo "Монтируем EFI раздел..."
mkdir /boot/efi
mount /dev/sdb1 /boot/efi

# Установка загрузчика GRUB для UEFI
echo "Устанавливаем загрузчик GRUB для UEFI..."
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --efi-directory=/boot/efi --recheck

# Генерация конфигурации GRUB
echo "Генерируем конфигурацию GRUB..."
grub-mkconfig -o /boot/grub/grub.cfg

# Установка драйвера для Intel
echo "Устанавливаем драйвер для Intel..."
pacman -S --noconfirm xf86-video-intel

# Установка Bspwm и необходимых компонентов
echo "Устанавливаем Bspwm и необходимые компоненты..."
pacman -S --noconfirm bspwm sxhkd alacritty dmenu polybar picom xorg-server xorg-xinit lightdm lightdm-gtk-greeter

# Включаем LightDM
echo "Включаем LightDM..."
systemctl enable lightdm
