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
    private readonly IEnrollmentRepository _enrollmentRepository;
    private readonly IUnitOfWork _unitOfWork;

    public CreateStudentUseCase(
        IPersonRepository personRepository,
        IEducationalPersonRepository educationalPersonRepository,
        IStudentRepository studentRepository,
        IFamiliarRepository familiarRepository,
        IEnrollmentRepository enrollmentRepository,
        IUnitOfWork unitOfWork)
    {
        _personRepository = personRepository;
        _educationalPersonRepository = educationalPersonRepository;
        _studentRepository = studentRepository;
        _familiarRepository = familiarRepository;
        _enrollmentRepository = enrollmentRepository;
        _unitOfWork = unitOfWork;
    }

    private async Task EnsurePersonDoesNotExistAsync(int documentTypeId, string documentNumber)
    {
        var existingId = await _personRepository.FindByDocumentAsync(documentTypeId, documentNumber);
        if (existingId != null)
            throw new InvalidOperationException("Esta persona ya está registrada. Se ha confundido de DNI?");
    }

    public async Task<int> ExecuteAsync(CreateStudentDTO dto)
    {
        await EnsurePersonDoesNotExistAsync(dto.DocumentTypeId, dto.IdDocumentNumber);

        var enrollmentDto = dto.Enrollment;
        var sectionId = await _enrollmentRepository.FindSectionIdAsync(
            enrollmentDto.SchoolYearId, enrollmentDto.GradeId, enrollmentDto.ShiftId, enrollmentDto.SectionId);

        if (sectionId == null)
            throw new KeyNotFoundException("La sección indicada no existe o no corresponde al año escolar, grado y turno especificados.");

        await _unitOfWork.BeginAsync();
        try
        {
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
            await _enrollmentRepository.CreateAsync(personId, sectionId.Value, enrollmentDto.SchoolFeeConceptId, enrollmentDto.SchoolYearId, enrollmentDto.PreviousSchool);

            await _unitOfWork.CommitAsync();
            return personId;
        }
        catch
        {
            await _unitOfWork.RollbackAsync();
            throw;
        }
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
