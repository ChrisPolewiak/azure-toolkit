from flask import *
from werkzeug.utils import secure_filename
import os
import AzurePlan


app = Flask(__name__, template_folder = os.path.abspath('template'))
app.config['TEMPLATES_AUTO_RELOAD'] = True
app.config['UPLOAD_FOLDER'] = os.path.abspath('uploads')
app.config['SECRET_KEY'] = 'yt83t0ghasyg0j'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024


ALLOWED_EXTENSIONS = {'csv', 'xls', 'xlsx', 'txt'}
def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


@app.route('/', methods=['GET'])
def index():
    return render_template('index.html')


@app.route('/import', methods=['GET', 'POST'])
def upload_file():
    if request.method == 'POST':
        if request.files:
            uploaded_file = request.files['file']

            if uploaded_file and allowed_file(uploaded_file.filename):
                filepath = os.path.join(app.config['UPLOAD_FOLDER'], secure_filename(uploaded_file.filename)) 
                uploaded_file.save(filepath)

                report = AzurePlan.Import(filepath)
                billing = AzurePlan.Calculate(report)
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
