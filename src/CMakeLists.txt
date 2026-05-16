find_package(Qt5Core REQUIRED)
find_package(Qt5Gui REQUIRED)
find_package(Qt5Qml REQUIRED)
find_package(Qt5Quick REQUIRED)
find_package(Qt5Multimedia REQUIRED)
find_package(Qt5Network REQUIRED)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 14)

set(SRC_FILES
    main.cpp
    audiorecorder.cpp
    audiorecorder.h
    whisperclient.cpp
    whisperclient.h
    ttsclient.cpp
    ttsclient.h
    timeutil.cpp
    timeutil.h
)

add_executable(${PROJECT_NAME} ${SRC_FILES})

target_link_libraries(${PROJECT_NAME}
    Qt5::Core
    Qt5::Gui
    Qt5::Qml
    Qt5::Quick
    Qt5::Multimedia
    Qt5::Network
)

install(TARGETS ${PROJECT_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX})
