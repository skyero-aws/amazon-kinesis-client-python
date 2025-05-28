python setup_list.py download_jars
python setup_list.py install
cd amazon_kclpy/jars
jar xf amazon-kinesis-client-multilang-3.0.3-SNAPSHOT.jar
cd -
python setup_list.py download_more_jars
python setup_list.py install_more
