FROM rhel7/rhel

RUN yum clean all && \
    yum update -y --setopt=tsflags=nodocs && \
    yum clean all

RUN yum install -y --setopt=tsflags=nodocs httpd-tools && \
    yum clean all

CMD ["ab", "-n", "100", "-c", "10", "http://www.redhat.com/"]
