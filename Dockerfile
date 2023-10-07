FROM mcr.microsoft.com/openjdk/jdk:11-ubuntu


# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes


RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    git \
    iputils-ping \
    libcurl4 \
    libunwind8 \
    netcat \
    libssl1.0 \
  && rm -rf /var/lib/apt/lists/*


# Add custom root certs
ADD root.crt /usr/local/share/ca-certificates/root.crt
RUN chmod 644 /usr/local/share/ca-certificates/root.crt && \
  update-ca-certificates


# Add Certs to Keytool for Java/Maven
RUN keytool -importcert -file /usr/local/share/ca-certificates/root.crt -cacerts -keypass changeit -storepass changeit -noprompt -alias InternalRootCA


RUN curl -LsS https://aka.ms/InstallAzureCLIDeb | bash \
  && rm -rf /var/lib/apt/lists/*


RUN curl -LsS https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -o packages-microsoft-prod.deb && \
 dpkg -i packages-microsoft-prod.deb && \
 rm packages-microsoft-prod.deb


# Install Compilers
RUN apt-get update && apt-get install -y --no-install-recommends \
    dotnet-sdk-6.0 \
    docker.io \
    apt-transport-https \
    maven


# Add Mavenrc file to set Certs for use
ADD .mavenrc /root/.mavenrc


# Add Maven settings
ADD settings.xml /root/.m2/settings.xml


# Install Powershell
RUN curl -LsS https://github.com/PowerShell/PowerShell/releases/download/v7.2.0/powershell-lts_7.2.0-1.deb_amd64.deb -o powershell-lts_7.2.0-1.deb_amd64.deb && \
 dpkg -i powershell-lts_7.2.0-1.deb_amd64.deb && \
 rm powershell-lts_7.2.0-1.deb_amd64.deb


# Install Ansible Components
RUN apt-get update && apt-get install -y gcc python-dev libkrb5-dev && \
    apt-get install python3-pip -y && \
    apt-get install openssh-client -y && \
    pip3 install --upgrade pip && \
    pip3 install --upgrade virtualenv && \
    pip3 install pywinrm[kerberos] && \
    apt install krb5-user -y && \ 
    pip3 install pywinrm && \
    pip3 install ansible && \
    pip3 install pyvmomi


# Add SSH Key
ADD ssh_priv_key /root/.ssh/id_rsa
ADD ssh_pub_key /root/.ssh/id_rsa.pub


RUN chmod 600 /root/.ssh/id_rsa && \
    chmod 600 /root/.ssh/id_rsa.pub


# Add Ansible.cfg
ADD ansible.cfg /root/.ansible.cfg


# Add Krb5.conf for Kerberos
ADD krb5.conf /etc/krb5.conf


# Install Ansible VMWare Community Collection
RUN ansible-galaxy collection install community.vmware
RUN pip install -r ~/.ansible/collections/ansible_collections/community/vmware/requirements.txt


ARG TARGETARCH=amd64
ARG AGENT_VERSION=2.194.0


WORKDIR /azp


RUN if [ "$TARGETARCH" = "amd64" ]; then \
      AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz; \
    else \
      AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-${TARGETARCH}-${AGENT_VERSION}.tar.gz; \
    fi; \
    curl -LsS "$AZP_AGENTPACKAGE_URL" | tar -xz



COPY ./start.sh .
RUN chmod +x *.sh


ENTRYPOINT [ "./start.sh" ].04
