FROM harbor.licc.ac.cn/proxy/pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime as base

ARG http_proxy
ARG https_proxy

# ---- Dependencies ----
FROM base AS dependencies

# Set environment variables to non-interactive to avoid prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Update the package list and install necessary packages
RUN sed -i "s/archive.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list &&  \
    apt-get update && \
    apt-get install -y \
        software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
        python3.10 \
        python3.10-venv \
        python3.10-distutils \
        python3.10-dev \
        python3-opencv \
        python3-pip \
        wget \
        git \
        libgl1 \
        libglib2.0-0 \
        pandoc \
        libreoffice \
        && rm -rf /var/lib/apt/lists/*
        
# Set Python 3.10 as the default python3
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

# ---- Packages ----
FROM dependencies AS packages

# 设置环境变量以配置 HTTP 代理和 HTTPS 代理，只有在传递构建参数时才会设置
ENV http_proxy=${http_proxy}
ENV https_proxy=${https_proxy}

# 安装 Python 依赖项
RUN if [ -n "$http_proxy" ]; then pip config set global.proxy ${http_proxy}; fi

COPY requirements-docker.txt /root/requirements-docker.txt
COPY detectron2-0.6-cp310-cp310-linux_x86_64.whl /root/detectron2-0.6-cp310-cp310-linux_x86_64.whl

# Create a virtual environment for MinerU
RUN python3 -m venv /opt/mineru_venv

# Activate the virtual environment and install necessary Python packages
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip install -U pip -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip install -U /root/detectron2-0.6-cp310-cp310-linux_x86_64.whl -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip install -r /root/requirements-docker.txt -U -i https://pypi.tuna.tsinghua.edu.cn/simple"

ENV http_proxy=
ENV https_proxy=

# ---- Release ----
FROM packages AS release

# Copy the configuration file template and set up the model directory
COPY magic-pdf.template.json /root/magic-pdf.json

# Set the models directory in the configuration file (adjust the path as needed)
RUN sed -i 's|/tmp/models|/opt/models|g' /root/magic-pdf.json
# RUN sed -i 's|cpu|cuda|g' /root/magic-pdf.json

# Create the models directory
RUN mkdir -p /opt/models

# Set the entry point to activate the virtual environment and run the command line tool
ENTRYPOINT ["/bin/bash", "-c", "source /opt/mineru_venv/bin/activate && exec \"$@\"", "--"]
