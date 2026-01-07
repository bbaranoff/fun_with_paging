# Utilisation de Debian Stretch pour la compatibilité avec les anciens compilateurs
FROM ubuntu:16.04

# Éviter les questions interactives lors de l'installation
ENV DEBIAN_FRONTEND=noninteractive

# 2. Installation des dépendances système
RUN apt-get update && apt-get install -y --force-yes \
    gcc-4.9 g++-4.9 gcc-5 g++-5 kmod build-essential \
    libgmp-dev libx11-6 libx11-dev flex libncurses5 libncurses5-dev libncursesw5 \
    libpcsclite-dev zlib1g-dev libmpfr-dev libmpc-dev lemon aptitude libtinfo-dev \
    libtool shtool autoconf git pkg-config make libtalloc-dev libfftw3-dev \
    libgnutls28-dev libssl-dev libxml2-dev bison alsa-oss wget curl patch automake \
    && apt-get clean

# 3. Configuration de update-alternatives (Priorité au 4.9 pour le firmware sdr)
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 10 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 20 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.9 10 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-5 20 && \
    update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 30 && \
    update-alternatives --set cc /usr/bin/gcc && \
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 30 && \
    update-alternatives --set c++ /usr/bin/g++ && \
    update-alternatives --set gcc /usr/bin/gcc-4.9 && \
    update-alternatives --set g++ /usr/bin/g++-4.9

WORKDIR /root

# 4. Installation de Texinfo 4.13 (requis pour le cross-compiler)
RUN apt-get remove -y texinfo && \
    wget http://ftp.gnu.org/gnu/texinfo/texinfo-4.13.tar.gz && \
    tar -xf texinfo-4.13.tar.gz && \
    cd texinfo-4.13 && ./configure && make && make install && \
    cd .. && rm -rf texinfo-4.13*

# 5. Installation de la chaîne de compilation ARM (GNU ARM Installer)
RUN git clone https://github.com/axilirator/gnu-arm-installer.git gnuarm && \
    cd gnuarm && \
    # Correction de l'URL de Newlib (sources.redhat.com est down/obsolète)
    sed -i 's|ftp://sources.redhat.com/pub/newlib/|https://sourceware.org/pub/newlib/|g' download.sh && \
    ./download.sh && \
    ./build.sh
    
    
# 6. Compilation de libosmocore
RUN git clone https://github.com/osmocom/libosmocore && \
    cd libosmocore && git checkout 1.1.0 && autoreconf -i && ./configure && make && make install && ldconfig

# 7. Compilation de libosmo-dsp
RUN git clone https://github.com/osmocom/libosmo-dsp && \
    cd libosmo-dsp && git checkout 0.4.0 && autoreconf -i && ./configure && make && make install

COPY fun_with_paging_4f0acac4c1fa538082f54cb14bef0841aa9c8abb.diff /root
COPY *.sh /root

# 8. Compilation de OsmocomBB (Branche TRX avec support TX)
RUN git clone https://github.com/osmocom/osmocom-bb trx && \
    cd trx && \
    git checkout 4f0acac4c1fa538082f54cb14bef0841aa9c8abb && \
    cp /root/fun_with_paging_4f0acac4c1fa538082f54cb14bef0841aa9c8abb.diff . && \
    patch -p1 < fun_with_paging_4f0acac4c1fa538082f54cb14bef0841aa9c8abb.diff && \
    update-alternatives --set gcc /usr/bin/gcc-5 && \
    update-alternatives --set g++ /usr/bin/g++-5 && \
    cd src && \
    # Activation du support TX dans le Makefile
    sed -i 's/#CFLAGS += -DCONFIG_TX_ENABLE/CFLAGS += -DCONFIG_TX_ENABLE/' target/firmware/Makefile && \
    export PATH=$PATH:/root/gnuarm/install/bin/ && \
    make HOST_layer23_CONFARGS=--enable-transceiver
