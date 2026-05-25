#pragma once

#include <glm/glm.hpp>

class Camera {
public:
    Camera(glm::vec3 position, float yawDegrees, float pitchDegrees);

    glm::mat4 viewMatrix() const;
    glm::vec3 position() const { return m_position; }
    glm::vec3 forward() const { return m_front; }

    void moveForward(float amount);
    void moveRight(float amount);
    void moveUp(float amount);
    void look(float deltaX, float deltaY);

private:
    void updateVectors();

    glm::vec3 m_position;
    glm::vec3 m_front;
    glm::vec3 m_right;
    glm::vec3 m_up;
    glm::vec3 m_worldUp;
    float m_yaw;
    float m_pitch;
};
