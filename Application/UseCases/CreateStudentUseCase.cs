using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.Mappers;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

public class CreateStudentUseCase
{
    private readonly IPersonRepository _personRepository;
    private readonly IEducationalPersonRepository _educationalPersonRepository;
    private readonly IStudentRepository _studentRepository;
    private readonly IFamiliarRepository _familiarRepository;

    public CreateStudentUseCase(
        IPersonRepository personRepository,
        IEducationalPersonRepository educationalPersonRepository,
        IStudentRepository studentRepository,
        IFamiliarRepository familiarRepository)
    {
        _personRepository = personRepository;
        _educationalPersonRepository = educationalPersonRepository;
        _studentRepository = studentRepository;
        _familiarRepository = familiarRepository;
    }

    private async Task EnsurePersonDoesNotExistAsync(int documentTypeId, string documentNumber)
    {
        var existingId = await _personRepository.FindByDocumentAsync(documentTypeId, documentNumber);
        if (existingId != null)
            throw new InvalidOperationException("Esta persona ya está registrada. Se ha confundido de DNI?");
    }

    private static void PrintDTO(CreateStudentDTO dto)
    {
        Console.WriteLine("=== CreateStudentDTO ===");
        Console.WriteLine($"  Names:             {dto.Names}");
        Console.WriteLine($"  PaternalLastname:  {dto.PaternalLastname}");
        Console.WriteLine($"  MaternalLastname:  {dto.MaternalLastname}");
        Console.WriteLine($"  GenderId:          {dto.GenderId}");
        Console.WriteLine($"  BirthDate:         {dto.BirthDate}");
        Console.WriteLine($"  DocumentTypeId:    {dto.DocumentTypeId}");
        Console.WriteLine($"  IdDocumentNumber:  {dto.IdDocumentNumber}");
        Console.WriteLine($"  ReligionId:        {dto.ReligionId}");
        Console.WriteLine($"  CivilStateId:      {dto.CivilStateId}");
        Console.WriteLine($"  Address:           {dto.Address}");
        Console.WriteLine($"  AddressLocation:   Dept={dto.AddressLocation?.DepartmentId} Prov={dto.AddressLocation?.ProvinceId} Dist={dto.AddressLocation?.DistrictId}");
        Console.WriteLine($"  Email:             {dto.Email}");
        Console.WriteLine($"  LandlinePhone:     {dto.LandlinePhone}");
        Console.WriteLine($"  CellPhone:         {dto.CellPhone}");
        Console.WriteLine($"  NativeLanguageId:  {dto.NativeLanguageId}");
        Console.WriteLine($"  EthnicSelfIdentId: {dto.EthnicSelfIdentificationId}");
        Console.WriteLine($"  SecondLanguageIds: [{string.Join(", ", dto.SecondLanguageIds ?? [])}]");
        Console.WriteLine($"  BirthLocation:     Dept={dto.BirthLocation?.DepartmentId} Prov={dto.BirthLocation?.ProvinceId} Dist={dto.BirthLocation?.DistrictId}");
        Console.WriteLine($"  HasElectronicDev:  {dto.HasElectronicDevices}");
        Console.WriteLine($"  HasInternetAccess: {dto.HasInternetAccess}");
        Console.WriteLine($"  HasDisability:     {dto.HasDisability}");
        Console.WriteLine($"  Siblings:          {dto.Siblings}");
        Console.WriteLine($"  ChildbirthTypeId:  {dto.ChildbirthTypeId}");
        Console.WriteLine($"  Familiars ({dto.Familiars.Count}):");
        foreach (var f in dto.Familiars)
            Console.WriteLine($"    - {f.Names} {f.PaternalLastname} | Doc={f.IdDocumentNumber} | RelId={f.RelationshipId} | Guardian={f.IsGuardian}");
        Console.WriteLine("=======================");
    }

    public async Task<int> ExecuteAsync(CreateStudentDTO dto)
    {
        PrintDTO(dto);
        await EnsurePersonDoesNotExistAsync(dto.DocumentTypeId, dto.IdDocumentNumber);

        var student = StudentMapper.FromDTO(dto);

        var personId = await _personRepository.CreateAsync(student);

        await _educationalPersonRepository.CreateAsync(personId, student.NativeLanguageId, student.EthnicSelfIdentificationId);

        if (student.SecondLanguageIds != null && student.SecondLanguageIds.Count > 0)
            await _educationalPersonRepository.AddSecondLanguagesAsync(personId, student.SecondLanguageIds);

        await _studentRepository.CreateAsync(student, personId);
        await _studentRepository.CreateHomeAsync(student, personId);

        foreach (var familiar in student.Familiars)
        {
            var familiarPersonId = await ResolveFamiliarAsync(familiar);
            await _familiarRepository.CreateRelationshipAsync(familiar, familiarPersonId, personId);
        }

        return personId;
    }

    private async Task<int> ResolveFamiliarAsync(DFamiliar familiar)
    {
        var existingPersonId = await _personRepository.FindByDocumentAsync(familiar.DocumentTypeId, familiar.IdDocumentNumber);
        int personId;
        if (existingPersonId == null)
        {
            personId = await _personRepository.CreateAsync(StudentMapper.PersonFromFamiliar(familiar));
        }
        else
        {
            personId = existingPersonId.Value;
        }

        var epExists = await _educationalPersonRepository.ExistsByPersonIdAsync(personId);
        if (!epExists)
        {
            await _educationalPersonRepository.CreateAsync(personId, familiar.NativeLanguageId, familiar.EthnicSelfIdentificationId);
            if (familiar.SecondLanguageIds != null && familiar.SecondLanguageIds.Count > 0)
                await _educationalPersonRepository.AddSecondLanguagesAsync(personId, familiar.SecondLanguageIds);
        }

        var familiarExists = await _familiarRepository.ExistsByEducationalPersonIdAsync(personId);
        if (!familiarExists)
            await _familiarRepository.CreateAsync(familiar, personId);

        return personId;
    }
}
