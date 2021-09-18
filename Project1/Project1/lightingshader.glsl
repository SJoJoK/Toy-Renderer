#version 330 core
out vec4 FragColor;
in vec3 Normal;
in vec3 FragPos;
uniform vec3 lightPos;
uniform vec3 objectColor;
uniform vec3 lightColor;
uniform vec3 viewPos;
void main()
{
    vec3 norm = normalize(Normal);
    vec3 lightDir = normalize(lightPos - FragPos);
    vec3 viewDir = normalize(viewPos-FragPos);
    vec3 reflectDir = reflect(-lightDir, norm);

    float ambientStrength = 0.1;
    float specularStrength = 0.5;
    float shininess = 32;
    float diff = max(dot(norm, lightDir), 0.0);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
    
    vec3 ambient = ambientStrength * lightColor;
  
    vec3 diffuse = diff * lightColor;

    vec3 specular = specularStrength * spec * lightColor;
    
    vec3 result = (ambient+diffuse+specular) * objectColor;

    FragColor = vec4(result, 1.0);
}