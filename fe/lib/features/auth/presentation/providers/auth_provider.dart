import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:fe/core/network/api_exception.dart';
import 'package:fe/core/storage/token_storage.dart';
import 'package:fe/features/auth/domain/dtos/forgot_password_req.dart';
import 'package:fe/features/auth/domain/dtos/login_req.dart';
import 'package:fe/features/auth/domain/dtos/register_req.dart';
import 'package:fe/features/auth/domain/dtos/verify_email_req.dart';
import 'package:fe/features/auth/domain/models/role.dart';
import 'package:fe/features/auth/domain/models/user_res.dart';
import 'package:fe/features/auth/data/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService authService;
  final TokenStorage tokenStorage;

  UserRes? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  String? _errorMessage;
  String? _pendingEmail;

  AuthProvider({required this.authService, required this.tokenStorage});

  UserRes? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get pendingEmail => _pendingEmail;
  bool get isAuthenticated => _accessToken != null && _currentUser != null;

  void setPendingEmail(String? email) {
    _pendingEmail = email;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> load() async {
    try {
      final token = await tokenStorage.getAccessToken();
      final refresh = await tokenStorage.getRefreshToken();
      final user = await tokenStorage.getUser();

      if (token != null && user != null) {
        _accessToken = token;
        _refreshToken = refresh;
        _currentUser = user;
        notifyListeners();
      }
    } catch (_) {
      await logout();
    }
  }

  Future<void> checkAuth() async {
    try {
      final token = await tokenStorage.getAccessToken();
      final refresh = await tokenStorage.getRefreshToken();
      final user = await tokenStorage.getUser();

      if (token != null && user != null) {
        _accessToken = token;
        _refreshToken = refresh;
        _currentUser = user;
        notifyListeners();
      }
    } catch (_) {
      await logout();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    required UserRole expectedRole,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      String fingerprint = 'flutter-${defaultTargetPlatform.name}';
      String platform = defaultTargetPlatform.name;
      String? name;
      try {
        final info = DeviceInfoPlugin();
        if (defaultTargetPlatform == TargetPlatform.android) {
          final data = await info.androidInfo;
          fingerprint = data.id;
          platform = 'android';
          name = '${data.manufacturer} ${data.model}';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final data = await info.iosInfo;
          fingerprint = data.identifierForVendor ?? data.name;
          platform = 'ios';
          name = data.name;
        }
      } catch (_) {
        // Fallback to default platform fingerprint in test/unsupported environments
      }
      final res = await authService.login(
        LoginReq(email: username.trim(), password: password,
          deviceFingerprint: expectedRole == UserRole.staff ? fingerprint : null,
          deviceName: expectedRole == UserRole.staff ? name : null,
          devicePlatform: expectedRole == UserRole.staff ? platform : null),
      );

      // Phân quyền theo cổng đăng nhập
      if (expectedRole == UserRole.staff) {
        if (res.user.role != UserRole.staff &&
            res.user.role != UserRole.admin &&
            res.user.role != UserRole.device) {
          throw const ApiException(
            'Tài khoản không có quyền truy cập cổng Nhân viên.',
          );
        }
      } else if (expectedRole == UserRole.reader) {
        if (res.user.role != UserRole.reader) {
          throw const ApiException(
            'Vui lòng sử dụng cổng đăng nhập Nhân viên.',
          );
        }
      }

      _accessToken = res.accessToken;
      _refreshToken = res.refreshToken;
      _currentUser = res.user;

      await tokenStorage.saveTokens(
        accessToken: res.accessToken,
        refreshToken: res.refreshToken,
      );
      await tokenStorage.saveUser(res.user);

      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await authService.register(
        RegisterReq(
          username: username.trim(),
          email: email.trim(),
          password: password,
          displayName: displayName?.trim(),
        ),
      );
      _pendingEmail = res.email.isNotEmpty ? res.email : email.trim();
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Đăng ký thất bại: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifyEmail({
    required String email,
    required String code,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await authService.verifyEmail(
        VerifyEmailReq(email: email.trim(), code: code.trim()),
      );
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Xác thực email thất bại: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resendCode({required String email}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await authService.resendCode(email.trim());
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Gửi lại mã OTP thất bại: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> forgotPassword({required String email}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await authService.forgotPassword(ForgotPasswordReq(email: email.trim()));
      _pendingEmail = email.trim();
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Yêu cầu đặt lại mật khẩu thất bại: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifyResetOtp({
    required String email,
    required String code,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await authService.verifyResetOtp(email: email.trim(), code: code.trim());
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Xác minh OTP thất bại: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await authService.resetPassword(
        email: email.trim(),
        newPassword: newPassword,
      );
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Đặt lại mật khẩu thất bại: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    _errorMessage = null;
    _pendingEmail = null;
    await tokenStorage.clear();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
