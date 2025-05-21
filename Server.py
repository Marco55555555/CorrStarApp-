from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict, Optional, Union

import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression, LogisticRegression, HuberRegressor, RANSACRegressor
from sklearn.feature_selection import SelectKBest, f_regression, RFE
from sklearn.metrics import (r2_score, accuracy_score, confusion_matrix, 
                           roc_curve, roc_auc_score, mean_absolute_error, 
                           mean_squared_error, explained_variance_score,f1_score, confusion_matrix)
from scipy.stats import pearsonr, spearmanr, kendalltau
import tempfile
import os
from pydantic import BaseModel
import statsmodels.api as sm
import statsmodels.formula.api as smf
import seaborn as sns
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from io import BytesIO
import base64
from mpl_toolkits.mplot3d import Axes3D
from sklearn.model_selection import train_test_split, cross_val_score
import plotly.express as px
import plotly.graph_objects as go
import plotly.io as pio
import joblib
from datetime import datetime
import json
import uuid
from pathlib import Path
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis as LDA
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report
import plotly.figure_factory as ff
from typing import List, Dict, Optional, Literal
from patsy import dmatrix  



app = FastAPI(
    title="API de Análisis Estadístico",
    description="API para cálculo de correlaciones y modelos de regresión",
    version="1.0.0"
)

# Configuración CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MODELS_DIR = Path("saved_models")
MODELS_DIR.mkdir(exist_ok=True)


# Almacenamiento temporal de datos
global_data: Dict[str, Dict] = {}

@app.post("/upload-csv/")
async def upload_csv(file: UploadFile = File(...)):
    """Endpoint para subir archivo CSV"""
    try:
        # Crear archivo temporal
        with tempfile.NamedTemporaryFile(delete=False) as temp_file:
            content = await file.read()
            temp_file.write(content)
            temp_file_path = temp_file.name
        
        # Leer CSV
        df = pd.read_csv(temp_file_path)
        os.unlink(temp_file_path)  # Eliminar archivo temporal
        
        # Almacenar datos
        file_id = str(len(global_data) + 1)
        global_data[file_id] = {
            "dataframe": df,
            "columns": df.columns.tolist()
        }
        
        return {
            "file_id": file_id,
            "columns": df.columns.tolist(),
            "row_count": len(df)
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error al procesar el archivo: {str(e)}")

class CorrelationRequest(BaseModel):
    variables: List[str]
    method: str = "pearson"  # por defecto

@app.post("/calculate-correlation/{file_id}")
async def calculate_correlation(file_id: str, req: CorrelationRequest):
    variables = req.variables
    method = req.method.lower()

    if len(variables) < 2:
        raise HTTPException(status_code=400, detail="Selecciona al menos 2 variables")
    
    if file_id not in global_data:
        raise HTTPException(status_code=404, detail="Archivo no encontrado")
    
    if "dummy_encoded" in global_data[file_id]:
        df = global_data[file_id]["dummy_encoded"]

    elif "ordinal_encoded" in global_data[file_id]:
        df = global_data[file_id]["ordinal_encoded"]
    else:
        df = global_data[file_id]["dataframe"]


    for var in variables:
        if var not in df.columns:
            raise HTTPException(status_code=400, detail=f"Variable {var} no encontrada")

    numeric_df = df[variables].apply(pd.to_numeric, errors='coerce').dropna()
    
    if len(numeric_df) < 2:
        raise HTTPException(status_code=400, detail="No hay suficientes datos válidos para calcular correlaciones")

    correlation_matrix = []
    
    for i, var1 in enumerate(variables):
        row = []
        for j, var2 in enumerate(variables):
            if i == j:
                row.append(1.0)
            elif i < j:
                if method == "pearson":
                    corr, _ = pearsonr(numeric_df[var1], numeric_df[var2])
                elif method == "spearman":
                    corr, _ = spearmanr(numeric_df[var1], numeric_df[var2])
                elif method == "kendall":
                    corr, _ = kendalltau(numeric_df[var1], numeric_df[var2])
                else:
                    raise HTTPException(status_code=400, detail="Método de correlación no válido")
                row.append(float(corr))
            else:
                row.append(correlation_matrix[j][i])
        correlation_matrix.append(row)

    return {
        "variables": variables,
        "method": method,
        "correlation_matrix": correlation_matrix
    }

##funciones
def quote(name: str) -> str:
    return f'Q("{name}")'

def clean_json_data(obj):
    if isinstance(obj, float):
        if np.isnan(obj) or np.isinf(obj):
            return None
        return obj
    elif isinstance(obj, dict):
        return {k: clean_json_data(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [clean_json_data(i) for i in obj]
    else:
        return obj
    
def generate_interactive_plot(fig):
    """Convierte gráfico Plotly a HTML para frontend"""
    return fig.to_html(full_html=False, include_plotlyjs='cdn')

def save_model_to_disk(model, model_type: str, metadata: dict) -> str:
    """Guarda modelo en disco y devuelve ID único"""
    model_id = str(uuid.uuid4())
    model_path = MODELS_DIR / f"{model_id}.joblib"
    
    save_data = {
        'model': model,
        'metadata': metadata,
        'created_at': datetime.now().isoformat(),
        'model_type': model_type
    }
    
    joblib.dump(save_data, model_path)
    return model_id

def load_model_from_disk(model_id: str):
    """Carga modelo desde disco"""
    model_path = MODELS_DIR / f"{model_id}.joblib"
    if not model_path.exists():
        return None
    return joblib.load(model_path)
######################

class LinearRegressionRequest(BaseModel):
    target: str
    features: List[str]

@app.post("/train-linear-regression/{file_id}")
async def train_linear_regression(file_id: str, req: LinearRegressionRequest):
    target = req.target
    features = req.features

    if not target or not features:
        raise HTTPException(status_code=400, detail="Faltan variables objetivo o predictoras")

    if file_id not in global_data:
        raise HTTPException(status_code=404, detail="Archivo no encontrado")

    if "dummy_encoded" in global_data[file_id]:
        df = global_data[file_id]["dummy_encoded"]
    elif "ordinal_encoded" in global_data[file_id]:
        df = global_data[file_id]["ordinal_encoded"]
    else:
        df = global_data[file_id]["dataframe"]


    if target not in df.columns:
        raise HTTPException(status_code=400, detail=f"Variable objetivo {target} no encontrada")

    for feature in features:
        if feature not in df.columns:
            raise HTTPException(status_code=400, detail=f"Variable predictora {feature} no encontrada")

    all_vars = [target] + features
    missing = [col for col in all_vars if col not in df.columns]
    if missing:
        raise HTTPException(status_code=400, detail=f"Columnas no encontradas: {missing}")
    
    df = df[all_vars].apply(pd.to_numeric, errors='coerce').dropna()


    if len(df) < 2:
        raise HTTPException(status_code=400, detail="No hay suficientes datos válidos para entrenar el modelo")

    # Entrenar modelo
    quoted_target = quote(target)
    quoted_features = [quote(f) for f in features]
    formula = f"{quoted_target} ~ " + " + ".join(quoted_features)
    model = smf.ols(formula=formula, data=df).fit()

    coef = model.params
    intercept = coef.iloc[0]
    equation = f"{target} = {intercept:.4f} + " + " + ".join([f"{coef[i]:.4f}*{i}" for i in coef.index[1:]])

    anova_table = None
    if len(features) > 1:
        anova = sm.stats.anova_lm(model, typ=2)
        anova_table = anova.reset_index().to_dict(orient="records")

    # Gráfico de residuales
    fig, ax = plt.subplots()
    ax.scatter(model.fittedvalues, model.resid)
    ax.axhline(0, color='red', linestyle='--')
    ax.set_xlabel("Predicción")
    ax.set_ylabel("Residuales")
    ax.set_title("Residuales vs Predicción")
    buf = BytesIO()
    plt.tight_layout()
    plt.savefig(buf, format='png')
    plt.close(fig)
    residuals_plot = base64.b64encode(buf.getvalue()).decode('utf-8')

    # Visualización 2D o 3D
    visual_plot = None
    if len(features) == 1:
        fig, ax = plt.subplots()
        ax.scatter(df[features[0]], df[target], label="Datos")
        ax.plot(df[features[0]], model.fittedvalues, color='red', label="Recta")
        ax.set_xlabel(features[0])
        ax.set_ylabel(target)
        ax.set_title("Ajuste 2D")
        ax.legend()
        buf = BytesIO()
        plt.tight_layout()
        plt.savefig(buf, format='png')
        plt.close(fig)
        visual_plot = base64.b64encode(buf.getvalue()).decode('utf-8')
    elif len(features) == 2:
        fig = plt.figure()
        ax = fig.add_subplot(111, projection='3d')
        ax.scatter(df[features[0]], df[features[1]], df[target], c='blue', label='Datos')
        xx, yy = np.meshgrid(
            np.linspace(df[features[0]].min(), df[features[0]].max(), 10),
            np.linspace(df[features[1]].min(), df[features[1]].max(), 10),
        )
        zz = intercept + coef[1]*xx + coef[2]*yy
        ax.plot_surface(xx, yy, zz, alpha=0.3, color='red')
        ax.set_xlabel(features[0])
        ax.set_ylabel(features[1])
        ax.set_zlabel(target)
        ax.set_title("Ajuste 3D")
        buf = BytesIO()
        plt.tight_layout()
        plt.savefig(buf, format='png')
        plt.close(fig)
        visual_plot = base64.b64encode(buf.getvalue()).decode('utf-8')

    result = {
        "target": target,
        "features": features,
        "coefficients": coef.iloc[1:].tolist(),
        "intercept": intercept,
        "p_values": model.pvalues.iloc[1:].tolist(),
        "intercept_p_value": model.pvalues.iloc[0].item(),
        "r_squared": model.rsquared,
        "equation": equation,
        "anova": anova_table,
        "residuals_plot": residuals_plot,
        "visual_plot": visual_plot,
    }

    return clean_json_data(result)


class LogisticRegressionRequest(BaseModel):
    target: str
    features: List[str]

@app.post("/train-logistic-regression/{file_id}")
async def train_logistic_regression(file_id: str, req: LogisticRegressionRequest):
    target = req.target
    features = req.features

    if file_id not in global_data:
        raise HTTPException(status_code=404, detail="Archivo no encontrado")

    if "dummy_encoded" in global_data[file_id]:
        df = global_data[file_id]["dummy_encoded"]
    elif "ordinal_encoded" in global_data[file_id]:
        df = global_data[file_id]["ordinal_encoded"]
    else:
        df = global_data[file_id]["dataframe"]



    if target not in df.columns:
        raise HTTPException(status_code=400, detail=f"Variable objetivo {target} no encontrada")

    for feature in features:
        if feature not in df.columns:
            raise HTTPException(status_code=400, detail=f"Variable predictora {feature} no encontrada")

    all_vars = [target] + features
    numeric_df = df[all_vars].apply(pd.to_numeric, errors='coerce').dropna()

    if len(numeric_df) < 2:
        raise HTTPException(status_code=400, detail="No hay suficientes datos válidos para entrenar el modelo")

    unique_values = numeric_df[target].unique()
    if len(unique_values) != 2:
        raise HTTPException(
            status_code=400,
            detail="La variable objetivo debe tener exactamente 2 valores para regresión logística"
        )

    # Partir los datos en 70% train, 30% test
    X = numeric_df[features]
    y = numeric_df[target]
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3,stratify=y,random_state=42)

    # Ajustar el modelo con statsmodels
    X_train_const = sm.add_constant(X_train)
    model = sm.Logit(y_train, X_train_const).fit(disp=0)

    # Predicción
    X_test_const = sm.add_constant(X_test, has_constant='add')
    y_pred_prob = model.predict(X_test_const)
    y_pred = (y_pred_prob >= 0.5).astype(int)

    # Métricas
    accuracy = accuracy_score(y_test, y_pred)
    conf_matrix = confusion_matrix(y_test, y_pred)
    fpr, tpr, _ = roc_curve(y_test, y_pred_prob)
    auc_score = roc_auc_score(y_test, y_pred_prob)

    # Tabla de coeficientes
    summary_frame = model.summary2().tables[1].reset_index()
    summary_table = summary_frame.rename(columns={
        'index': 'Variable',
        'Coef.': 'Coefficient',
        'Std.Err.': 'Std_Error',
        'z': 'Z_value',
        'P>|z|': 'P_value'
    }).to_dict(orient="records")

    # Matriz de confusión (gráfico)
    fig, ax = plt.subplots()
    sns.heatmap(conf_matrix, annot=True, fmt='d', cmap='Blues', ax=ax)
    ax.set_xlabel('Predicho')
    ax.set_ylabel('Real')
    ax.set_title('Matriz de Confusión')
    buf = BytesIO()
    plt.tight_layout()
    plt.savefig(buf, format='png')
    plt.close(fig)
    conf_matrix_img = base64.b64encode(buf.getvalue()).decode('utf-8')

    # Curva ROC (gráfico)
    fig, ax = plt.subplots()
    ax.plot(fpr, tpr, label=f'AUC = {auc_score:.2f}')
    ax.plot([0, 1], [0, 1], linestyle='--', color='grey')
    ax.set_xlabel('False Positive Rate')
    ax.set_ylabel('True Positive Rate')
    ax.set_title('Curva ROC')
    ax.legend()
    buf = BytesIO()
    plt.tight_layout()
    plt.savefig(buf, format='png')
    plt.close(fig)
    roc_curve_img = base64.b64encode(buf.getvalue()).decode('utf-8')

    return {
        "target": target,
        "features": features,
        "summary_table": summary_table,
        "accuracy": accuracy,
        "auc": auc_score,
        "confusion_matrix_image": conf_matrix_img,
        "roc_curve_image": roc_curve_img,
        "model_type": "logistic_regression"
    }

@app.get("/list-files/")
async def list_files():
    """Lista todos los archivos cargados"""
    return {
        "files": [
            {
                "file_id": file_id,
                "columns": data["columns"],
                "row_count": len(data["dataframe"])
            }
            for file_id, data in global_data.items()
        ]
    }

@app.delete("/remove-file/{file_id}")
async def remove_file(file_id: str):
    """Elimina un archivo cargado"""
    if file_id in global_data:
        del global_data[file_id]
        return {"message": f"Archivo {file_id} eliminado"}
    raise HTTPException(status_code=404, detail="Archivo no encontrado")


class AutoCategoricalEncodingRequest(BaseModel):
    file_id: str
    columns: List[str]
    column_types: Optional[Dict[str, Literal["ordinal", "nominal"]]] = {}

@app.post("/encode-categoricals-auto/")
async def encode_categoricals_auto(req: AutoCategoricalEncodingRequest):
    if req.file_id not in global_data:
        raise HTTPException(status_code=404, detail="Archivo no encontrado")

    df_original = global_data[req.file_id]["dataframe"].copy()
    df_encoded = df_original.copy()
    encoding_maps = {}

    for col in req.columns:
        if col not in df_encoded.columns:
            raise HTTPException(status_code=400, detail=f"Columna '{col}' no existe en el dataset")

        if not pd.api.types.is_object_dtype(df_encoded[col]) and not pd.api.types.is_categorical_dtype(df_encoded[col]):
            raise HTTPException(status_code=400, detail=f"Columna '{col}' no es categórica")

        # Determinar si es ordinal o nominal
        encoding_type = req.column_types.get(col, "nominal")  # por defecto nominal

        if encoding_type == "ordinal":
            freq_order = df_encoded[col].value_counts().index.tolist()
            mapping = {cat: i for i, cat in enumerate(freq_order)}
            df_encoded[col + "_ordinal"] = df_encoded[col].map(mapping)
            encoding_maps[col] = {"type": "ordinal", "mapping": mapping}
        else:  # nominal
            dummies = pd.get_dummies(df_encoded[col], prefix=col, dtype=int)
            df_encoded = pd.concat([df_encoded, dummies], axis=1)
            encoding_maps[col] = {"type": "nominal", "dummies": dummies.columns.tolist()}

    global_data[req.file_id]["dummy_encoded"] = df_encoded
    global_data[req.file_id]["encoding_maps"] = encoding_maps

    return {
        "message": "Codificación aplicada sin sobrescribir columnas originales",
        "columns_encoded": list(encoding_maps.keys()),
        "encoding_maps": encoding_maps,
        "preview": df_encoded.head(10).fillna("").to_dict(orient="records")
    }


class TrainLDARequest(BaseModel):
    target: str
    features: List[str]
    

@app.post("/train-lda/{file_id}")
def train_lda(file_id: str, req: TrainLDARequest):
    try:
        if file_id not in global_data:
            raise HTTPException(status_code=404, detail="Archivo no encontrado")

        if "dummy_encoded" in global_data[file_id]:
            df = global_data[file_id]["dummy_encoded"]
        elif "ordinal_encoded" in global_data[file_id]:
            df = global_data[file_id]["ordinal_encoded"]
        else:
            df = global_data[file_id]["dataframe"]

        # Validación de columnas
        missing = [f for f in req.features if f not in df.columns]
        if req.target not in df.columns or missing:
            raise HTTPException(
                status_code=400,
                detail=f"Columnas no encontradas: {missing + [req.target] if req.target not in df.columns else missing}"
            )

        # Preprocesamiento
        X = df[req.features].apply(pd.to_numeric, errors='coerce').dropna()
        y_raw = df.loc[X.index, req.target]
        le = LabelEncoder()
        y = le.fit_transform(y_raw)
        class_names = le.classes_.tolist()

        n_classes = len(class_names)
        n_components = min(X.shape[1], n_classes - 1)

        if n_components < 1:
            raise HTTPException(status_code=400, detail="Se requieren al menos 2 clases para LDA")

        # Entrenamiento
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.3, random_state=42, stratify=y
        )
        lda = LDA(n_components=n_components)
        X_train_lda = lda.fit_transform(X_train, y_train)
        y_pred = lda.predict(X_test)

        # Métricas
        accuracy = accuracy_score(y_test, y_pred)
        f1 = f1_score(y_test, y_pred, average='weighted')
        auc_score = roc_auc_score(y_test, lda.predict_proba(X_test)[:, 1]) if n_classes == 2 else None

        # --- Generación de Gráficos ---
        def fig_to_base64(fig):
            buf = BytesIO()
            fig.savefig(buf, format='png', dpi=100, bbox_inches='tight')
            plt.close(fig)  # ¡Importante!
            return base64.b64encode(buf.getvalue()).decode('utf-8')

        # Matriz de confusión
        fig, ax = plt.subplots()
        sns.heatmap(confusion_matrix(y_test, y_pred), annot=True, fmt='d', cmap='Blues', ax=ax)
        ax.set_title("Matriz de Confusión")
        conf_matrix_img = fig_to_base64(fig)

        # Scree plot
        fig, ax = plt.subplots()
        ax.bar(range(1, n_components+1), lda.explained_variance_ratio_)
        ax.set_title("Varianza Explicada por Componente")
        scree_plot_img = fig_to_base64(fig)

        # Proyección 2D (si aplica)
        proj_2d = None
        if n_components >= 2:
            fig, ax = plt.subplots()
            for i, class_name in enumerate(class_names):
                mask = (y_train == i)
                ax.scatter(X_train_lda[mask, 0], X_train_lda[mask, 1], label=class_name)
            ax.set_title("Proyección LDA 2D")
            ax.legend()
            proj_2d = fig_to_base64(fig)

        # Proyección 3D (si aplica)
        proj_3d = None
        if n_components >= 3:
            fig = plt.figure()
            ax = fig.add_subplot(111, projection='3d')
            for i, class_name in enumerate(class_names):
                mask = (y_train == i)
                ax.scatter(X_train_lda[mask, 0], X_train_lda[mask, 1], X_train_lda[mask, 2], label=class_name)
            ax.set_title("Proyección LDA 3D")
            ax.legend()
            proj_3d = fig_to_base64(fig)

        return {
            "metrics": {
                "accuracy": accuracy,
                "f1_score": f1,
                "auc_roc": auc_score,
                "confusion_matrix": confusion_matrix(y_test, y_pred).tolist(),
                "class_names": class_names,
                "explained_variance": lda.explained_variance_ratio_.tolist()
            },
            "plots": {
                "confusion_matrix": conf_matrix_img,
                "scree_plot": scree_plot_img,
                "projection_2d": proj_2d,
                "projection_3d": proj_3d
            }
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/preview/{file_id}")
async def preview_file(file_id: str, encoded: Optional[bool] = False):
    """Devuelve una muestra del archivo original o codificado"""
    if file_id not in global_data:
        raise HTTPException(status_code=404, detail="Archivo no encontrado")

    df = None
    if encoded and "dummy_encoded" in global_data[file_id]:
        df = global_data[file_id]["dummy_encoded"]
    else:
        df = global_data[file_id]["dataframe"]

    return {
        "preview": df.head(10).fillna("").to_dict(orient="records"),
        "columns": df.columns.tolist(),
        "row_count": len(df)
    }



