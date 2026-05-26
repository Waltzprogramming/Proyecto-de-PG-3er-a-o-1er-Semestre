#include "Camera.h"

#include <glm/gtc/matrix_transform.hpp>

#include <algorithm>
#include <cmath>

Camera::Camera(glm::vec3 position, float yawDegrees, float pitchDegrees)
    : m_position(position),
      m_worldUp(0.0f, 1.0f, 0.0f),
      m_yaw(yawDegrees),
      m_pitch(pitchDegrees) {
    updateVectors();
}

glm::mat4 Camera::viewMatrix() const {
    return glm::lookAt(m_position, m_position + m_front, m_up);
}

void Camera::moveForward(float amount) {
    m_position += m_front * amount;
}

void Camera::moveRight(float amount) {
    m_position += m_right * amount;
}

void Camera::moveUp(float amount) {
    m_position += m_worldUp * amount;
}

void Camera::look(float deltaX, float deltaY) {
    const float sensitivity = 0.09f;
    m_yaw += deltaX * sensitivity;
    m_pitch += deltaY * sensitivity;
    m_pitch = std::clamp(m_pitch, -84.0f, 84.0f);
    updateVectors();
}

void Camera::updateVectors() {
    const float yaw = glm::radians(m_yaw);
    const float pitch = glm::radians(m_pitch);
    glm::vec3 front;
    front.x = std::cos(yaw) * std::cos(pitch);
    front.y = std::sin(pitch);
    front.z = std::sin(yaw) * std::cos(pitch);
    m_front = glm::normalize(front);
    m_right = glm::normalize(glm::cross(m_front, m_worldUp));
    m_up = glm::normalize(glm::cross(m_right, m_front));
}
