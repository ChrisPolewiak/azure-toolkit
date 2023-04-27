from flask import *
import uuid_utils as uuid
from werkzeug.utils import secure_filename
import os
import AzurePlan
from opencensus.ext.azure.trace_exporter import AzureExporter
from opencensus.ext.flask.flask_middleware import FlaskMiddleware
from opencensus.trace.samplers import ProbabilitySampler

app = Flask(__name__, template_folder = os.path.abspath('template'))
app.config['TEMPLATES_AUTO_RELOAD'] = True
app.config['UPLOAD_FOLDER'] = os.path.abspath('uploads')
app.config['SECRET_KEY'] = 'yt83t0ghasyg0j'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024

# For website monitoring
AzureAppInsights_ConnectionString = 'InstrumentationKey=3712782d-691c-47d4-bef1-52ae3c0f7dc1;IngestionEndpoint=https://northeurope-2.in.applicationinsights.azure.com/;LiveEndpoint=https://northeurope.livediagnostics.monitor.azure.com/'

if AzureAppInsights_ConnectionString:
    middleware = FlaskMiddleware(
        app,
        exporter=AzureExporter( connection_string=AzureAppInsights_ConnectionString ),
        sampler=ProbabilitySampler(rate=1.0),
    )


ALLOWED_EXTENSIONS = {'csv', 'xls', 'xlsx', 'txt'}
def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# Default webpage - form
@app.route('/', methods=['GET'])
def index():
    return render_template('index.html')


# Import and report
@app.route('/import', methods=['GET', 'POST'])
def upload_file():
    if request.method == 'POST':
        if request.files:
            uploaded_file = request.files['file']

            if uploaded_file and allowed_file(uploaded_file.filename):
                filepath = os.path.join(app.config['UPLOAD_FOLDER'], str(uuid.uuid4()) + '_' + secure_filename(uploaded_file.filename)) 
                uploaded_file.save(filepath)

                report = AzurePlan.Import(filepath)
                billing = AzurePlan.Calculate(report)
                os.unlink( filepath )
                return render_template('report.html', report=billing)
            else:
                print("wrong filename")
        else:
            print("no files")
    else:
        print("not post")
    return redirect('/')


if __name__ == '__main__':
    app.secret_key = 'super secret key'
    app.config['SESSION_TYPE'] = 'filesystem'
    app.debug = False
    app.run()
