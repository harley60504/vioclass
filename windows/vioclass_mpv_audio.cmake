# Full LGPL libmpv, x86_64 baseline (not v3). Keep the Dart/ANGLE plugins intact.
# Immutable release + SHA256; never download a moving "latest" binary.
set(VIOCLASS_MPV_VERSION "2026-10-09-fd9265a905")
set(VIOCLASS_MPV_ARCHIVE_NAME "mpv-dev-lgpl-x86_64-20261009-git-fd9265a905.7z")
set(VIOCLASS_MPV_SHA256 "9847d016c1d9704cb550b691eb69ce58500e8531256b0aa01427f4d1629ea3da")
set(VIOCLASS_MPV_ROOT "${CMAKE_BINARY_DIR}/vioclass_mpv/${VIOCLASS_MPV_VERSION}")
set(VIOCLASS_MPV_ARCHIVE "${VIOCLASS_MPV_ROOT}/${VIOCLASS_MPV_ARCHIVE_NAME}")
file(MAKE_DIRECTORY "${VIOCLASS_MPV_ROOT}")
if(NOT EXISTS "${VIOCLASS_MPV_ARCHIVE}")
  file(DOWNLOAD
    "https://github.com/zhongfly/mpv-winbuild/releases/download/${VIOCLASS_MPV_VERSION}/${VIOCLASS_MPV_ARCHIVE_NAME}"
    "${VIOCLASS_MPV_ARCHIVE}"
    EXPECTED_HASH "SHA256=${VIOCLASS_MPV_SHA256}"
    TLS_VERIFY ON STATUS VIOCLASS_MPV_DOWNLOAD_STATUS)
  list(GET VIOCLASS_MPV_DOWNLOAD_STATUS 0 VIOCLASS_MPV_DOWNLOAD_CODE)
  if(NOT VIOCLASS_MPV_DOWNLOAD_CODE EQUAL 0)
    message(FATAL_ERROR "VioClass libmpv download failed: ${VIOCLASS_MPV_DOWNLOAD_STATUS}")
  endif()
endif()
file(SHA256 "${VIOCLASS_MPV_ARCHIVE}" VIOCLASS_MPV_ACTUAL_SHA256)
if(NOT VIOCLASS_MPV_ACTUAL_SHA256 STREQUAL VIOCLASS_MPV_SHA256)
  message(FATAL_ERROR "VioClass libmpv SHA256 mismatch; refusing unverified runtime")
endif()
if(NOT EXISTS "${VIOCLASS_MPV_ROOT}/libmpv-2.dll")
  execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf "${VIOCLASS_MPV_ARCHIVE}"
    WORKING_DIRECTORY "${VIOCLASS_MPV_ROOT}" RESULT_VARIABLE VIOCLASS_MPV_EXTRACT_CODE)
  if(NOT VIOCLASS_MPV_EXTRACT_CODE EQUAL 0)
    message(FATAL_ERROR "VioClass libmpv extraction failed")
  endif()
endif()
if(NOT EXISTS "${VIOCLASS_MPV_ROOT}/libmpv-2.dll")
  message(FATAL_ERROR "VioClass full libmpv DLL missing from pinned archive")
endif()
file(SHA256 "${VIOCLASS_MPV_ROOT}/libmpv-2.dll" VIOCLASS_MPV_DLL_SHA256)
if(NOT VIOCLASS_MPV_DLL_SHA256 STREQUAL
    "48276397da952e9c5e8ca8423dd17dfa05e1ad7b2011fa0c5a9038a96838c4d7")
  message(FATAL_ERROR "VioClass libmpv DLL hash mismatch; refusing modified runtime")
endif()
# The archive uses the same name preferred by the media_kit loader.
list(FILTER PLUGIN_BUNDLED_LIBRARIES EXCLUDE REGEX "[/\\]libmpv-2\\.dll$")
list(APPEND PLUGIN_BUNDLED_LIBRARIES "${VIOCLASS_MPV_ROOT}/libmpv-2.dll")
