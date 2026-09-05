#! /usr/bin/env bash
#
# Copyright (C) 2013-2015 Bilibili
# Copyright (C) 2013-2015 Zhang Rui <bbcallen@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# A symlink that MSYS could not create leaves a text file containing the
# target name; regenerate module.sh from the default profile in that case.
if [ ! -f 'config/module.sh' ] || ! grep -q 'COMMON_FF_CFG_FLAGS' config/module.sh 2>/dev/null; then
    cp config/module-lite.sh config/module.sh
fi