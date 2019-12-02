FROM ubuntu:16.04
RUN apt update && \
  apt install -y qemu-kvm qemu-utils bridge-utils dnsmasq uml-utilities iptables wget net-tools genisoimage && \
  apt autoclean && apt autoremove
ENV QCOW2_URL ""
ADD startvm.sh /
ENTRYPOINT ["bash", "/startvm.sh"]
