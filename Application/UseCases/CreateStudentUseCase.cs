using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.Mappers;
using SRJBackend.Domain.Entities;
using SRJBackend.Domain.ValueObjects;

namespace SRJBackend.Application.UseCases;

public class CreateStudentUseCase
{
    private readonly IPersonRepository _personRepository;
    private readonly IStudentRepository _studentRepository;
    private readonly IFamiliarRepository _familiarRepository;
    private readonly IEnrollmentRepository _enrollmentRepository;
    private readonly IGradeOfferingShiftSectionRepository _sectionRepository;
    private readonly GenerateEnrollmentChargesUseCase _generateCharges;
    private readonly IUnitOfWork _unitOfWork;

    public CreateStudentUseCase(
        IPersonRepository personRepository,
        IStudentRepository studentRepository,
        IFamiliarRepository familiarRepository,
        IEnrollmentRepository enrollmentRepository,
        IGradeOfferingShiftSectionRepository sectionRepository,
        GenerateEnrollmentChargesUseCase generateCharges,
        IUnitOfWork unitOfWork)
    {
        _personRepository = personRepository;
        _studentRepository = studentRepository;
        _familiarRepository = familiarRepository;
        _enrollmentRepository = enrollmentRepository;
        _sectionRepository = sectionRepository;
        _generateCharges = generateCharges;
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
        var sectionId = await _sectionRepository.FindValidSectionIdAsync(
            enrollmentDto.SchoolYearId, enrollmentDto.GradeId, enrollmentDto.ShiftId, enrollmentDto.SectionId);

        if (sectionId == null)
            throw new KeyNotFoundException("La sección indicada no existe o no corresponde al año escolar, grado y turno especificados.");

        await _unitOfWork.BeginAsync();
        try
        {
            var student = StudentMapper.FromDTO(dto);

            var personId = await _personRepository.CreateAsync(student);
            await _personRepository.UpdateDemographicsAsync(personId, student.Demographics.NativeLanguageId, student.Demographics.EthnicSelfIdentificationId);

            if (student.Demographics.SecondLanguageIds != null && student.Demographics.SecondLanguageIds.Count > 0)
                await _personRepository.AddSecondLanguagesAsync(personId, student.Demographics.SecondLanguageIds);

            await _studentRepository.CreateAsync(student, personId);
            await _studentRepository.CreateHomeAsync(student, personId);

            foreach (var familiar in student.Familiars)
            {
                var familiarPersonId = await ResolveFamiliarAsync(familiar);
                await _familiarRepository.CreateRelationshipAsync(familiar, familiarPersonId, personId);
            }
            var placement = new AcademicPlacement(enrollmentDto.LevelId, enrollmentDto.GradeId, enrollmentDto.ShiftId, sectionId.Value);
            var enrollment = await _enrollmentRepository.CreateAsync(personId, placement, enrollmentDto.SchoolFeeConceptId, enrollmentDto.SchoolYearId, enrollmentDto.PreviousSchool, isNew: true);

            // First-time enrollment → admission + enrollment debts.
            await _generateCharges.ExecuteAsync(enrollment, isNew: true, createdBy: null);

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
        var existingPersonId = await _personRepository.FindByDocumentAsync(familiar.Document.DocumentTypeId, familiar.Document.IdDocumentNumber);
        int personId;
        if (existingPersonId == null)
        {
            personId = await _personRepository.CreateAsync(StudentMapper.PersonFromFamiliar(familiar));
            await _personRepository.UpdateDemographicsAsync(personId, familiar.Demographics.NativeLanguageId, familiar.Demographics.EthnicSelfIdentificationId);
            if (familiar.Demographics.SecondLanguageIds != null && familiar.Demographics.SecondLanguageIds.Count > 0)
                await _personRepository.AddSecondLanguagesAsync(personId, familiar.Demographics.SecondLanguageIds);
        }
        else
        {
            personId = existingPersonId.Value;
        }

        var familiarExists = await _familiarRepository.ExistsByPersonIdAsync(personId);
        if (!familiarExists)
            await _familiarRepository.CreateAsync(familiar, personId);

        return personId;
    }
}
