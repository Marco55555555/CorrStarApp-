# CorrStarApp

**Autores:** Cristian Vega, Marco Jiménez  
**Carrera:** Ingeniería Estadística - Escuela Colombiana de Ingeniería Julio Garavito  
**Materia:** Modelos de Regresión

---

## Resumen

CorrStarApp es una aplicación multiplataforma que facilita el análisis estadístico de correlaciones y la construcción de modelos predictivos a través de una interfaz intuitiva y visual. Combina un backend desarrollado en FastAPI con un frontend en Flutter, logrando eficiencia, escalabilidad y una experiencia de usuario amigable.

---

## 1. Introducción

CorrStarApp nació como una herramienta básica para el cálculo de coeficientes de correlación (Pearson, Spearman y Kendall), con funcionalidades limitadas a la carga de archivos CSV y visualización simple.

La versión actual integra nuevos módulos para análisis estadístico avanzados como regresión lineal, regresión logística y análisis discriminante lineal (LDA). Además, cuenta con codificación automática de variables categóricas, validaciones estrictas de datos y visualizaciones interactivas que mejoran notablemente la experiencia del usuario y la capacidad analítica.

Su arquitectura modular basada en FastAPI (backend) y Flutter (frontend) facilita la escalabilidad y el mantenimiento, permitiendo futuras ampliaciones.

---

## 2. Objetivos

### Objetivo General  
Desarrollar una aplicación multiplataforma para realizar análisis estadístico de correlaciones y construir modelos predictivos de forma automatizada, accesible y visualmente clara para diversos usuarios.

### Objetivos Específicos

- Crear una interfaz gráfica intuitiva para cargar, visualizar y manipular datos estadísticos.  
- Automatizar el cálculo de coeficientes de correlación (Pearson, Spearman, Kendall) con validaciones.  
- Implementar modelos estadísticos interpretables: regresión lineal, regresión logística y análisis discriminante lineal (LDA).  
- Diseñar visualizaciones interactivas para facilitar la interpretación de resultados.  
- Incorporar codificación automática para variables categóricas y validación de datos.  
- Garantizar rendimiento y escalabilidad para manejar grandes volúmenes de datos.

---

## 3. Tecnologías y Herramientas

- **Frontend:** Flutter  
  - Paquetes: http, file_picker, provider, flutter_hooks, json_serializable  
- **Backend:** FastAPI  
- **Librerías Python:** Pandas, Scikit-learn, Statsmodels, Matplotlib, Seaborn  
- **Entorno:** Visual Studio Code, Postman  
- **SO:** Windows 11  
- **Hardware:** Portátil Intel Core i5, 8GB RAM

---

## 4. Metodología

El desarrollo se dividió en cinco fases:

1. **Análisis y diseño:** Requerimientos, elección tecnológica y arquitectura modular.  
2. **Backend:** Creación de endpoints para carga de datos, cálculos estadísticos y generación de gráficos.  
3. **Frontend:** Desarrollo de pantallas, integración API y diseño UI/UX.  
4. **Pruebas:** Unitarias, de integración y rendimiento.  
5. **Documentación:** Elaboración de manuales y mejora continua basada en feedback.

---

## 5. Resultados

- Cálculo preciso de coeficientes de correlación.  
- Modelos estadísticos robustos con métricas como R², Accuracy y AUC.  
- Interfaz amigable, responsiva y visualmente clara.  
- Visualizaciones automáticas: gráficos de dispersión, curvas ROC, scree plots, proyecciones LDA.  
- Capacidad para procesar archivos de hasta 1 millón de registros manteniendo buen rendimiento.

---

## 6. Conclusiones

CorrStarApp representa un avance importante en herramientas accesibles para análisis estadístico, pasando de un enfoque básico a una plataforma integral que combina facilidad de uso y profundidad analítica. Su arquitectura modular y escalable facilita mantenimiento y futuras mejoras.

Es una solución ideal para estudiantes y profesionales que requieren análisis estadísticos rápidos, confiables y fáciles de interpretar gracias a su interfaz visual y funcionalidades avanzadas.

---
