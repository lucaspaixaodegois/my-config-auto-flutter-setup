# 🚀 Flutter Auto Setup (Windows)

[![Powershell](https://shields.io)](https://github.com)
[![Flutter](https://shields.io)](https://flutter.dev)
[![Author](https://shields.io)](https://github.com)

Script inteligente desenvolvido por **Lucas Paixão** para automação completa do ambiente Flutter no Windows. Ideal para novas máquinas ou padronização de ambientes.

## ✨ Diferenciais
- **Dry-Run Mode:** Simule a instalação sem alterar arquivos no sistema.
- **Escolha de Drive:** Instale no `C:`, `D:`, ou qualquer unidade disponível.
- **Auto-Elevation:** Solicita privilégios de Administrador automaticamente.
- **Smart Path:** Configura `JAVA_HOME`, `FLUTTER_HOME` e PATH instantaneamente.

## 🛠️ O que é automatizado?


| Ferramenta | Ação |
| :--- | :--- |
| **Chocolatey** | Gerenciador de pacotes base |
| **Git & OpenJDK** | Dependências essenciais do sistema |
| **Flutter SDK** | Download e configuração da versão Stable |
| **Android SDK** | Command-line Tools e aceite de licenças |
| **Opcionais** | FVM, 7Zip e Android Studio |

## 🚀 Como usar

### Opção A: Atalho Rápido (Recomendado)
1. Baixe o [ZIP do projeto](https://github.com/my-config-auto-flutter-setup/archive/refs/heads/main.zip).
2. Extraia os arquivos.
3. Clique com o botão direito em `install.bat` e selecione **Executar como Administrador**.

### Opção B: Via Terminal
```powershell
git clone https://github.com/my-config-auto-flutter-setup.git
cd my-config-auto-flutter-setup
./install.bat
