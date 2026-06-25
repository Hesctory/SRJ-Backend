namespace SRJBackend.Application.DTOs;

public class RegistrationCardDTO
{
    public int id { get; set; }
    public string? enrollmentCode { get; set; }
    public string? enrollmentDate { get; set; }
    public string? schoolYear { get; set; }
    public string? level { get; set; }
    public string? grade { get; set; }
    public string? section { get; set; }
    public string? shift { get; set; }
    public string? paternalLastName { get; set; }
    public string? maternalLastName { get; set; }
    public string? firstName { get; set; }
    public string? birthDate { get; set; }
    public string? birthPlace { get; set; }
    public string? birthCountry { get; set; }
    public string? gender { get; set; }
    public string? religion { get; set; }
    public string? dni { get; set; }
    public int? siblings { get; set; }
    public int? siblingPosition { get; set; }
    public string? disability { get; set; }
    public string? previousSchool { get; set; }
    public string? address { get; set; }
    public string? district { get; set; }
    public RegistrationCardParentDTO? mother { get; set; }
    public RegistrationCardParentDTO? father { get; set; }
    public RegistrationCardGuardianDTO? guardian { get; set; }
    public RegistrationCardFeesDTO fees { get; set; } = new();
}

public class RegistrationCardParentDTO
{
    public string? paternalLastName { get; set; }
    public string? maternalLastName { get; set; }
    public string? firstName { get; set; }
    public string? dni { get; set; }
    public string? phone { get; set; }
    public string? email { get; set; }
    public string? educationLevel { get; set; }
    public string? occupation { get; set; }
    public string? maritalStatus { get; set; }
}

public class RegistrationCardGuardianDTO
{
    public string? relationship { get; set; }
    public string? paternalLastName { get; set; }
    public string? maternalLastName { get; set; }
    public string? firstName { get; set; }
    public string? dni { get; set; }
    public string? phone { get; set; }
    public string? email { get; set; }
}

public class RegistrationCardFeesDTO
{
    public decimal registrationFee { get; set; }
    public decimal registrationDiscount { get; set; } = 0.00m;
    public decimal enrollmentFee { get; set; }
    public decimal enrollmentDiscount { get; set; } = 0.00m;
    public decimal tuition { get; set; }
    public decimal tuitionDiscount { get; set; } = 0.00m;
}
