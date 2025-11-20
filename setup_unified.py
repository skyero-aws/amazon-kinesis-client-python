# Copyright 2014-2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
from __future__ import print_function

import glob
import sys
import os
import shutil
import json
import xml.etree.ElementTree as ET
import zipfile

from setuptools import Command
from setuptools import setup
from setuptools.command.install import install

if sys.version_info[0] >= 3:
    from urllib.request import urlopen
else:
    from urllib2 import urlopen

PACKAGE_NAME = 'amazon_kclpy'
JAR_DIRECTORY = os.path.join(PACKAGE_NAME, 'jars')
PACKAGE_VERSION = '3.0.3'
PYTHON_REQUIREMENTS = [
    'boto3',
    'argparse',
]
REMOTE_MAVEN_PACKAGES_FILE = 'pom.xml'
DEPENDENCY_JSON_DIR = 'amazon_kclpy/jars/pom-sync/multilang_dependencies.json'

class UnifiedJarDownloader:
    def __init__(self, destdir=JAR_DIRECTORY):
        self.destdir = destdir
        self.pom_packages = self.parse_packages_from_pom()
        self.json_packages = self.parse_packages_from_json()

    def parse_packages_from_pom(self):
        try:
            maven_root = ET.parse(REMOTE_MAVEN_PACKAGES_FILE).getroot()
            maven_version = '{http://maven.apache.org/POM/4.0.0}'
            properties = {f"${{{child.tag.replace(maven_version, '')}}}": child.text
                          for child in maven_root.find(f'{maven_version}properties').iter() if 'version' in child.tag}

            packages = []
            for dep in maven_root.iter(f'{maven_version}dependency'):
                dependency = []
                for attr in ['groupId', 'artifactId', 'version']:
                    val = dep.find(maven_version + attr).text
                    if val in properties:
                        dependency.append(properties[val])
                    else:
                        dependency.append(val)
                packages.append(tuple(dependency))
            return packages
        except Exception as e:
            print(f"Error parsing POM: {e}")
            return []

    def parse_packages_from_json(self):
        try:
            with open(DEPENDENCY_JSON_DIR, 'r') as file:
                data = json.load(file)
                packages = []
                for dependency in data.get('dependencies', []):
                    if all(key in dependency for key in ['groupId', 'artifactId', 'version']):
                        packages.append((dependency['groupId'].strip(),
                                       dependency['artifactId'].strip(),
                                       dependency['version'].strip()))
                return packages
        except Exception as e:
            print(f"Error parsing JSON dependencies: {e}")
            return []

    def unzip_jar_if_needed(self):
        jar_path = "amazon_kclpy/jars/amazon-kinesis-client-multilang-3.0.3-SNAPSHOT.jar"
        if os.path.exists(jar_path):
            try:
                with zipfile.ZipFile(jar_path, 'r') as jar:
                    jar.extractall(self.destdir)
                print(f"JAR file extracted to: {self.destdir}")
            except Exception as e:
                print(f"Error unzipping JAR: {e}")

    def download_all_jars(self):
        # First unzip the main JAR if it exists
        self.unzip_jar_if_needed()

        # Download from both POM and JSON sources
        all_packages = self.pom_packages + self.json_packages
        for package in all_packages:
            self.download_jar(package)

    def download_jar(self, package):
        group_id, artifact_id, version = package
        dest = os.path.join(self.destdir, f'{artifact_id}-{version}.jar')

        if os.path.isfile(dest):
            print(f'Skipping download of {dest}')
            return

        prefix = os.getenv("KCL_MVN_REPO_SEARCH_URL", 'https://repo1.maven.org/maven2/')
        url = f'{prefix}{"/".join(group_id.split("."))}/{artifact_id}/{version}/{artifact_id}-{version}.jar'

        try:
            print(f'Downloading {url}')
            response = urlopen(url)
            with open(dest, 'wb') as dest_file:
                shutil.copyfileobj(response, dest_file)
            print(f'Saved {url} -> {dest}')
        except Exception as e:
            print(f'Failed to retrieve {url}: {e}')

class DownloadJarsCommand(Command):
    description = "Download all jar files needed to run the sample application"
    user_options = []

    def initialize_options(self):
        pass

    def finalize_options(self):
        pass

    def run(self):
        downloader = UnifiedJarDownloader()
        downloader.download_all_jars()

class InstallWithJars(install):
    def run(self):
        # Download all jars first
        downloader = UnifiedJarDownloader()
        downloader.download_all_jars()

        # Then run the standard installation
        install.run(self)

if __name__ == '__main__':
    setup(
        name=PACKAGE_NAME,
        version=PACKAGE_VERSION,
        description='A python interface for the Amazon Kinesis Client Library MultiLangDaemon',
        license='Apache-2.0',
        packages=[PACKAGE_NAME, PACKAGE_NAME + "/v2", PACKAGE_NAME + "/v3", 'samples'],
        scripts=glob.glob('samples/*py'),
        package_data={
            '': ['*.txt', '*.md'],
            PACKAGE_NAME: ['jars/*'],
            'samples': ['sample.properties'],
        },
        install_requires=PYTHON_REQUIREMENTS,
        setup_requires=["pytest-runner"],
        tests_require=["pytest", "mock"],
        cmdclass={
            'download_jars': DownloadJarsCommand,
            'install': InstallWithJars,
        },
        url="https://github.com/awslabs/amazon-kinesis-client-python",
        keywords="amazon kinesis client library python",
        zip_safe=False,
    )